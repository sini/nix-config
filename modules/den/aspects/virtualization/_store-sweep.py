"""microvm-store-sweep: delete guest images and root sets the configuration no longer names.

docs/microvm-persistent-store.md §2.4. Deletes every <scratch-root>/*.img and every
<roots-dir>/* outside the keep-set, except an image some process holds open and the root
set of an unconfigured guest that is still running.
"""

import argparse
import os
import shutil
import subprocess
import sys


def plan(images, root_dirs, keep_images, keep_roots, configured, open_images, active):
    """Return (images to delete, root dirs to delete), both sorted.

    images, keep_images, open_images: image paths; root_dirs, keep_roots: guest names;
    configured: guests the configuration names; active: guests whose microvm@ is active.
    """
    del_images = sorted(i for i in images if i not in keep_images and i not in open_images)
    del_roots = sorted(
        r
        for r in root_dirs
        if r not in keep_roots and not (r not in configured and r in active)
    )
    return del_images, del_roots


def open_inodes():
    """(st_dev, st_ino) of every file some process holds open."""
    held = set()
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        fd_dir = f"/proc/{pid}/fd"
        try:
            fds = os.listdir(fd_dir)
        except OSError:
            continue
        for fd in fds:
            try:
                st = os.stat(f"{fd_dir}/{fd}")
            except OSError:
                continue
            held.add((st.st_dev, st.st_ino))
    return held


def is_active(name):
    r = subprocess.run(
        ["systemctl", "is-active", "--quiet", f"microvm@{name}.service"], check=False
    )
    return r.returncode == 0


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--scratch-root", required=True)
    ap.add_argument("--roots-dir", required=True)
    ap.add_argument("--keep-image", action="append", default=[])
    ap.add_argument("--keep-roots", action="append", default=[])
    ap.add_argument("--configured", action="append", default=[])
    a = ap.parse_args(argv)

    images = []
    if os.path.isdir(a.scratch_root):
        images = [
            os.path.join(a.scratch_root, n)
            for n in os.listdir(a.scratch_root)
            if n.endswith(".img")
        ]
    root_dirs = os.listdir(a.roots_dir) if os.path.isdir(a.roots_dir) else []

    held = open_inodes() if images else set()
    open_images = set()
    for i in images:
        try:
            st = os.lstat(i)
        except FileNotFoundError:
            continue
        if (st.st_dev, st.st_ino) in held:
            open_images.add(i)
    candidates = [r for r in root_dirs if r not in a.keep_roots and r not in a.configured]
    active = {r for r in candidates if is_active(r)}

    del_images, del_roots = plan(
        images,
        root_dirs,
        set(a.keep_image),
        set(a.keep_roots),
        set(a.configured),
        open_images,
        active,
    )
    for i in sorted(open_images - set(a.keep_image)):
        print(f"kept (held open): {i}")
    for r in sorted(set(candidates) & active):
        print(f"kept (unconfigured guest still running): {r}")
    for i in del_images:
        print(f"deleting image {i}")
        os.unlink(i)
    for r in del_roots:
        p = os.path.join(a.roots_dir, r)
        print(f"deleting roots {p}")
        if os.path.isdir(p) and not os.path.islink(p):
            shutil.rmtree(p)
        else:
            os.unlink(p)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
