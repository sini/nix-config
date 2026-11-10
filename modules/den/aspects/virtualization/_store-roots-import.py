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


def plan_links(existing, wanted, store_dir):
    """(links to create, links to remove), both sorted; existing maps name -> target."""
    add = sorted(b for b in wanted if existing.get(b) != f"{store_dir}/{b}")
    remove = sorted(n for n in existing if n not in wanted)
    return add, remove


def read_export(state_dir, max_paths):
    limit = BYTES_PER_PATH * max_paths
    dfd = os.open(state_dir, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        try:
            sub = os.open(
                ".microvm-store",
                os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
                dir_fd=dfd,
            )
        except FileNotFoundError:
            raise NoExport() from None
        except OSError as e:
            raise Rejected(f".microvm-store: {e.strerror}") from None
        try:
            try:
                fd = os.open(
                    "roots",
                    os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
                    dir_fd=sub,
                )
            except FileNotFoundError:
                raise NoExport() from None
            except OSError as e:
                raise Rejected(f"roots: {e.strerror}") from None
            try:
                if not stat.S_ISREG(os.fstat(fd).st_mode):
                    raise Rejected("roots is not a regular file")
                buf = bytearray()
                while len(buf) <= limit:
                    b = os.read(fd, 1 << 20)
                    if not b:
                        break
                    buf += b
                if len(buf) > limit:
                    raise Rejected(f"roots exceeds {limit} bytes")
                return bytes(buf)
            finally:
                os.close(fd)
        finally:
            os.close(sub)
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
    ap.add_argument("--state-dir", required=True)
    ap.add_argument("--roots-dir", required=True)
    ap.add_argument("--store-dir", required=True)
    ap.add_argument("--gc-lock", required=True)
    ap.add_argument("--max-paths", type=int, required=True)
    a = ap.parse_args(argv)
    try:
        bases = parse(read_export(a.state_dir, a.max_paths), a.max_paths)
    except NoExport:
        # A guest that has not exported yet: nothing to apply, any previous set stays.
        print(f"{a.guest}: no export yet, previous root set kept")
        return 0
    except Rejected as e:
        print(f"{a.guest}: export rejected, previous root set kept: {e}", file=sys.stderr)
        return 1
    apply(a.roots_dir, a.guest, bases, a.store_dir, a.gc_lock)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
