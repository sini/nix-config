"""microvm-store-roots-import: apply a persistent-store guest's export as host GC roots.

docs/microvm-persistent-store.md §2.4. The export file is guest-written, so it is opened
without following anything the guest controls, read once through one fd, and parsed
strictly; a bad file fails the unit and leaves the previous root set as it was. The root
set is replaced under the host's GC lock, held shared, so a GC sees the old set or the
new one, never half of either.
"""

import argparse
import fcntl
import os
import re
import stat
import sys

LINE_RE = re.compile(r"^/nix/store/([0-9a-df-np-sv-z]{32}-[0-9A-Za-z+\-._?=]{1,211})$")
BYTES_PER_PATH = 256
EXPORT_NAME = "store-roots"
# A live guest's export always holds at least its system closure, which is lower-layer, so
# an empty export or one that drops nearly every held root is a broken export, never a real
# one; applying it would unroot the guest's state just before a host GC. Refuse it.
MAX_DROP_FRACTION = 0.9


class Rejected(Exception):
    pass


class NoExport(Exception):
    pass


def parse(data, max_paths):
    """The export's basenames; Rejected on any bad line or more than max_paths lines."""
    try:
        text = data.decode("ascii")
    except UnicodeDecodeError as e:
        raise Rejected(f"not ASCII: {e}") from None
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    if len(lines) > max_paths:
        raise Rejected(f"{len(lines)} lines exceed maxExportPaths={max_paths}")
    bases = []
    for n, line in enumerate(lines, 1):
        m = LINE_RE.match(line)
        if not m:
            raise Rejected(f"line {n} is not a store path: {line[:120]!r}")
        bases.append(m.group(1))
    return bases


def check_shrink(held, wanted):
    """Rejected when the export is empty or would drop more than MAX_DROP_FRACTION of `held`."""
    if not wanted:
        raise Rejected("empty export (a live guest always exports its system closure)")
    dropped = len(held - wanted)
    if held and dropped > MAX_DROP_FRACTION * len(held):
        raise Rejected(f"export drops {dropped} of {len(held)} held roots (over {MAX_DROP_FRACTION:.0%})")


def plan_links(existing, wanted, store_dir):
    """(links to create, links to remove), both sorted; existing maps name -> target."""
    add = sorted(b for b in wanted if existing.get(b) != f"{store_dir}/{b}")
    remove = sorted(n for n in existing if n not in wanted)
    return add, remove


def read_export(exchange_dir, max_paths):
    """The guest's export, read from the host-owned exchange directory without following
    anything the guest controls; NoExport when the guest has not exported yet."""
    limit = BYTES_PER_PATH * max_paths
    try:
        dfd = os.open(exchange_dir, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except FileNotFoundError:
        raise NoExport() from None
    except OSError as e:
        raise Rejected(f"{exchange_dir}: {e.strerror}") from None
    try:
        try:
            fd = os.open(
                EXPORT_NAME,
                os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
                dir_fd=dfd,
            )
        except FileNotFoundError:
            raise NoExport() from None
        except OSError as e:
            raise Rejected(f"{EXPORT_NAME}: {e.strerror}") from None
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode):
                raise Rejected(f"{EXPORT_NAME} is not a regular file")
            buf = bytearray()
            while len(buf) <= limit:
                b = os.read(fd, 1 << 20)
                if not b:
                    break
                buf += b
            if len(buf) > limit:
                raise Rejected(f"{EXPORT_NAME} exceeds {limit} bytes")
            return bytes(buf)
        finally:
            os.close(fd)
    finally:
        os.close(dfd)


def apply(roots_dir, guest, bases, store_dir, lock_path):
    present = []
    missing = 0
    for b in bases:
        try:
            os.lstat(os.path.join(store_dir, b))
            present.append(b)
        except FileNotFoundError:
            missing += 1
    wanted = set(present)

    lock = os.open(lock_path, os.O_RDWR | os.O_CREAT | os.O_CLOEXEC, 0o600)
    try:
        # Blocking: a long host GC delays the import, never skips it (§2.4 step 4).
        fcntl.flock(lock, fcntl.LOCK_SH)
        target = os.path.join(roots_dir, guest)
        os.makedirs(target, mode=0o755, exist_ok=True)
        existing = {}
        for n in os.listdir(target):
            p = os.path.join(target, n)
            existing[n] = os.readlink(p) if os.path.islink(p) else None
        check_shrink(set(existing), wanted)
        add, remove = plan_links(existing, wanted, store_dir)
        for b in add:
            p = os.path.join(target, b)
            tmp = os.path.join(target, f".{b}.tmp")
            if os.path.lexists(tmp):
                os.unlink(tmp)
            os.symlink(os.path.join(store_dir, b), tmp)
            os.replace(tmp, p)
        for n in remove:
            os.unlink(os.path.join(target, n))
    finally:
        os.close(lock)
    print(
        f"{guest}: {len(bases)} exported, {missing} already gone on the host, "
        f"{len(add)} roots added, {len(remove)} removed, {len(wanted)} held"
    )


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--guest", required=True)
    ap.add_argument("--exchange-dir", required=True)
    ap.add_argument("--roots-dir", required=True)
    ap.add_argument("--store-dir", required=True)
    ap.add_argument("--gc-lock", required=True)
    ap.add_argument("--max-paths", type=int, required=True)
    a = ap.parse_args(argv)
    try:
        bases = parse(read_export(a.exchange_dir, a.max_paths), a.max_paths)
    except NoExport:
        # A guest that has not exported yet: nothing to apply, any previous set stays.
        print(f"{a.guest}: no export yet, previous root set kept")
        return 0
    except Rejected as e:
        print(f"{a.guest}: export rejected, previous root set kept: {e}", file=sys.stderr)
        return 1
    try:
        apply(a.roots_dir, a.guest, bases, a.store_dir, a.gc_lock)
    except Rejected as e:
        print(f"{a.guest}: export rejected, previous root set kept: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
