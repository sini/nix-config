"""microvm-state-zvol: a guest's /persist and /cache on ZFS zvols (host side).

docs/microvm-persistent-store.md §2.10. Subcommands:
  volumes  create, format (only in the creating run) and grow each state zvol;
  migrate  move each state directory onto its zvol, one-way, resuming from what is on disk;
  guard    refuse a virtiofs start over a migrated (tombstoned) state directory;
  sweep    list leaked zvols, destroy the ones the host names, drop migrated backups.
Every decision is a pure function of what was observed; the rest only runs commands.
"""

import argparse
import datetime
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time

FORMATTED = "json64:formatted"
MIGRATED = "json64:migrated"
LINK_WAIT = 60


class Failed(Exception):
    pass


# --- pure pieces ---------------------------------------------------------------------


def format_action(exists, formatted):
    """What the volumes unit does with one zvol: "create", "format", "ok" or "refuse".

    formatted: the json64:formatted value, None when absent. "pending" is set by the
    `zfs create` itself, so only a run that created the zvol (or resumes one) formats.
    """
    if not exists:
        return "create"
    if formatted == "pending":
        return "format"
    if formatted == "1":
        return "ok"
    return "refuse"


def grow_action(have_bytes, want_bytes):
    """"grow", "ok" or "refuse" (a smaller declared size never shrinks a zvol)."""
    if want_bytes > have_bytes:
        return "grow"
    if want_bytes == have_bytes:
        return "ok"
    return "refuse"


def migrate_action(state, tmp, pre, migrated):
    """The next migration step for one state volume, from what is on disk.

    state, tmp, pre: "absent", "dir", "file" or "other" for <stateDir>, its temporary
    tombstone name and <stateDir>.pre-zvol; migrated: json64:migrated is set. Returns
    "done", "fresh" (write the tombstone: nothing to copy), "tombstone" (swap it in for
    the directory), "rename" (the swapped-out directory to .pre-zvol), "copy" (from
    .pre-zvol, then mark), "mark" (set json64:migrated), or "error".
    """
    if "other" in (state, tmp, pre) or pre == "file":
        return "error"
    if migrated:
        return "done" if state == "file" and tmp == "absent" else "error"
    if state == "absent":
        return "fresh" if pre == "absent" and tmp != "dir" else "error"
    if state == "dir":
        return "tombstone" if pre == "absent" and tmp != "dir" else "error"
    # state is the tombstone
    if tmp == "dir":
        return "rename" if pre == "absent" else "error"
    if tmp == "file":
        return "error"
    return "copy" if pre == "dir" else "mark"


def classify_zvols(zvols, parent, zvol_guests, configured, destroy, busy):
    """(leaked, destroyable), both sorted full names.

    zvols: full name -> json64:migrated set, for every zvol directly under `parent`.
    A zvol belongs to a guest when its name is <guest>-<volume>. Leaked: it belongs to no
    configured zvol guest, and is not a configured virtiofs guest's migrated zvol (a
    refused rollback, never a leak). Destroyable: listed in `destroy`, matching no
    configured guest under any backend, and not busy.
    """

    # shortcut: ownership is a <guest>- prefix, so a zvol of a removed guest whose name
    # extends a configured one's (uplink-dev-x under guest uplink) is not reported; exact
    # names per guest if guest names ever nest.
    def owners(name):
        short = name[len(parent) + 1 :]
        return {g for g in configured | zvol_guests if short.startswith(g + "-")}

    leaked = []
    for name, migrated in zvols.items():
        o = owners(name)
        if o & zvol_guests:
            continue
        if migrated and o:
            continue
        leaked.append(name)
    destroyable = [n for n in leaked if n in destroy and not owners(n) and n not in busy]
    return sorted(leaked), sorted(destroyable)


def drop_backup_ok(backend, migrated):
    """Whether a guest's .pre-zvol backups may go: zvol backend, every zvol migrated."""
    return backend == "zvol" and bool(migrated) and all(migrated)


# --- system --------------------------------------------------------------------------


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, text=True, stdout=subprocess.PIPE, **kw).stdout


def zfs_exists(name):
    return subprocess.run(["zfs", "list", "-H", "-o", "name", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0


def zfs_get(name, prop):
    v = run(["zfs", "get", "-Hp", "-o", "value", prop, name]).strip()
    return None if v == "-" else v


def kind(path):
    try:
        m = os.lstat(path).st_mode
    except FileNotFoundError:
        return "absent"
    if stat.S_ISDIR(m):
        return "dir"
    if stat.S_ISREG(m):
        return "file"
    return "other"


def dev_of(name):
    return f"/dev/zvol/{name}"


def wait_link(name):
    run(["udevadm", "settle"])
    link = dev_of(name)
    deadline = time.monotonic() + LINK_WAIT
    while not os.path.exists(link):
        if time.monotonic() > deadline:
            raise Failed(f"{link} did not appear within {LINK_WAIT}s")
        time.sleep(1)
    return link


def busy(name):
    """Something holds the zvol's device open (udev's watch probe settled first)."""
    run(["udevadm", "settle"])
    dev = os.path.realpath(dev_of(name))
    if not os.path.exists(dev):
        return True  # no device node to ask about: never treat that as idle
    return subprocess.run(["fuser", "-s", dev], check=False).returncode == 0


def write_synced(path, text):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_CLOEXEC, 0o600)
    try:
        os.write(fd, text.encode())
        os.fsync(fd)
    finally:
        os.close(fd)


def fsync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def pairs(xs):
    out = []
    for x in xs:
        k, sep, v = x.partition("=")
        if not sep:
            raise SystemExit(f"expected name=value, got {x!r}")
        out.append((k, v))
    return out


# --- volumes ---------------------------------------------------------------------------


def cmd_volumes(a):
    if not zfs_exists(a.parent):
        print(f"creating parent {a.parent}")
        run(["zfs", "create", "-p", "-o", "canmount=off", "-o", "mountpoint=none", a.parent])
    for short, size in pairs(a.vol):
        name = f"{a.parent}/{short}"
        exists = zfs_exists(name)
        act = format_action(exists, zfs_get(name, FORMATTED) if exists else None)
        if act == "refuse":
            raise Failed(f"{name} exists but {FORMATTED} is not 1 or pending; never formatting it")
        if act == "create":
            print(f"creating {name} ({size} MiB)")
            run(["zfs", "create", "-s", "-V", f"{size}M", "-o", "volmode=dev", "-o", "volblocksize=16K", "-o", "com.sun:auto-snapshot=true", "-o", f"{FORMATTED}=pending", name])
            link = wait_link(name)
            r = subprocess.run(["blkid", "-p", link], text=True, stdout=subprocess.PIPE, check=False)
            if r.returncode != 2:
                raise Failed(f"blkid -p {link} exited {r.returncode} ({r.stdout.strip()!r}): not provably empty; not formatting")
            run(["mkfs.ext4", "-q", "-E", "nodiscard", link])
            run(["zfs", "set", f"{FORMATTED}=1", name])
        elif act == "format":
            # A run that created the zvol died before marking it formatted: nothing has
            # opened it since (microvm@ requires this unit), so whatever is there goes.
            print(f"{name}: {FORMATTED}=pending, formatting")
            link = wait_link(name)
            run(["mkfs.ext4", "-q", "-F", "-E", "nodiscard", link])
            run(["zfs", "set", f"{FORMATTED}=1", name])
        want = int(size) * 1024 * 1024
        have = int(zfs_get(name, "volsize"))
        g = grow_action(have, want)
        if g == "refuse":
            raise Failed(f"{name}: declared {size} MiB is smaller than volsize {have} bytes; zvols only grow")
        if g == "grow":
            print(f"{name}: growing {have} -> {want} bytes")
            run(["zfs", "set", f"volsize={size}M", name])
    return 0


# --- migrate ---------------------------------------------------------------------------


def tombstone_text(name):
    now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
    return f"migrated to {name} at {now}\n"


def migrate_one(name, state_dir):
    tmp = state_dir + ".zvol-tombstone"
    pre = state_dir + ".pre-zvol"
    parent = os.path.dirname(state_dir)
    checked = False
    while True:
        migrated = zfs_get(name, MIGRATED) is not None
        act = migrate_action(kind(state_dir), kind(tmp), kind(pre), migrated)
        if act == "done":
            print(f"{name}: migrated")
            return
        if act == "error":
            raise Failed(f"{name}: unexpected state: {state_dir} {kind(state_dir)}, {tmp} {kind(tmp)}, {pre} {kind(pre)}, migrated={migrated}")
        if not checked:
            if zfs_get(name, FORMATTED) != "1":
                raise Failed(f"{name}: {FORMATTED} is not 1")
            if busy(name):
                raise Failed(f"{name}: held open; refusing to migrate onto a zvol in use")
            checked = True
        print(f"{name}: {act}")
        if act == "fresh":
            write_synced(tmp, tombstone_text(name))
            os.rename(tmp, state_dir)
            fsync_dir(parent)
        elif act == "tombstone":
            write_synced(tmp, tombstone_text(name))
            fsync_dir(parent)
            # renameat2(RENAME_EXCHANGE): state_dir is the tombstone from here on.
            run(["mv", "--exchange", "--no-target-directory", tmp, state_dir])
            fsync_dir(parent)
        elif act == "rename":
            os.rename(tmp, pre)
            fsync_dir(parent)
        elif act == "copy":
            mnt = tempfile.mkdtemp(prefix="microvm-state-")
            run(["mount", "-t", "ext4", dev_of(name), mnt])
            try:
                # Nothing has opened the zvol yet, so --delete only clears an interrupted copy.
                run(["rsync", "-aHAXS", "--numeric-ids", "--delete", "--exclude=/lost+found", pre + "/", mnt + "/"])
            finally:
                run(["umount", mnt])
                os.rmdir(mnt)
            act = "mark"
        if act == "mark":
            stamp = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
            run(["zfs", "set", f"{MIGRATED}={stamp}", name])


def cmd_migrate(a):
    for short, state_dir in pairs(a.vol):
        migrate_one(f"{a.parent}/{short}", state_dir)
    return 0


# --- guard -------------------------------------------------------------------------------


def cmd_guard(a):
    bad = []
    for d in a.state_dir:
        k = kind(d)
        if k == "dir":
            continue
        if k == "file":
            with open(d) as f:
                bad.append(f"{d}: {f.read().strip()}")
        else:
            bad.append(f"{d}: {k}, not a directory")
    if bad:
        raise Failed("refusing a virtiofs start: " + "; ".join(bad))
    return 0


# --- sweep -------------------------------------------------------------------------------


def list_zvols(parent):
    if not zfs_exists(parent):
        return {}
    out = {}
    for line in run(["zfs", "list", "-H", "-p", "-t", "volume", "-d", "1", "-o", f"name,{MIGRATED}", parent]).splitlines():
        name, migrated = line.split("\t")
        out[name] = migrated != "-"
    return out


def remove(path):
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path)
    elif os.path.lexists(path):
        os.unlink(path)


def cmd_sweep(a):
    for spec in a.drop_backup:
        d = json.loads(spec)
        migrated = [zfs_exists(z) and zfs_get(z, MIGRATED) is not None for z in d["zvols"]]
        if not drop_backup_ok(d["backend"], migrated):
            print(f"{d['guest']}: dropPreZvolBackup set, but not on zvol with every zvol migrated; backup kept")
            continue
        for p in d["paths"]:
            if os.path.lexists(p):
                print(f"{d['guest']}: deleting backup {p}")
                remove(p)
    if a.parent is None:
        return 0
    zvols = list_zvols(a.parent)
    destroy = set(a.destroy)
    held = {n for n in zvols if n in destroy and busy(n)}
    leaked, destroyable = classify_zvols(zvols, a.parent, set(a.zvol_guest), set(a.configured), destroy, held)
    for n in destroyable:
        print(f"destroying {n} (named in destroyStateZvols)")
        run(["zfs", "destroy", n])
    left = [n for n in leaked if n not in destroyable]
    if left:
        print(f"leaked state zvols (no configured zvol guest; destroy by listing them in destroyStateZvols): {' '.join(left)}", file=sys.stderr)
        return 1
    return 0


def main(argv):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="command", required=True)
    v = sub.add_parser("volumes")
    v.add_argument("--parent", required=True)
    v.add_argument("--vol", action="append", default=[], help="<zvol>=<MiB>")
    m = sub.add_parser("migrate")
    m.add_argument("--parent", required=True)
    m.add_argument("--vol", action="append", default=[], help="<zvol>=<stateDir>")
    g = sub.add_parser("guard")
    g.add_argument("--state-dir", action="append", default=[])
    s = sub.add_parser("sweep")
    s.add_argument("--parent")
    s.add_argument("--zvol-guest", action="append", default=[])
    s.add_argument("--configured", action="append", default=[])
    s.add_argument("--destroy", action="append", default=[])
    s.add_argument("--drop-backup", action="append", default=[], help="JSON: guest, backend, zvols, paths")
    a = ap.parse_args(argv)
    try:
        return {"volumes": cmd_volumes, "migrate": cmd_migrate, "guard": cmd_guard, "sweep": cmd_sweep}[a.command](a)
    except (Failed, subprocess.CalledProcessError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
