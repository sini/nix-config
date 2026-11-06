#!/usr/bin/env python3
"""List data in impermanence's stores (/persist, /cache) that no configured entry uses.

The manifest is the host's configured entries ({live, store, kind}) plus the paths
services use on a store directly (directPaths). A path under a store is:
  used      it is an entry's backing path, or inside one, or a direct path, or inside one
  parent    a used path lies beneath it, so it is walked
  orphan    neither: reported, with its size, and not walked
"""

import argparse
import json
import os
import stat
import sys


def load(manifest_path):
    with open(manifest_path) as f:
        m = json.load(f)
    used = {}
    for e in m["entries"]:
        store = e["store"].rstrip("/") or "/"
        used.setdefault(store, set()).add(os.path.normpath(store + e["live"]))
    for p in m.get("directPaths", []):
        p = os.path.normpath(p)
        for store, paths in used.items():
            if p == store or p.startswith(store + "/"):
                paths.add(p)
    return used


def apparent_size(path):
    """Apparent bytes under path (file lengths, as du --apparent-size), not crossing
    filesystems; unreadable parts count as 0. Deterministic, unlike allocated blocks,
    which ZFS reports for new data only after its transaction group commits."""
    try:
        st = os.lstat(path)
    except OSError:
        return 0
    if not stat.S_ISDIR(st.st_mode):
        return st.st_size
    total = 0
    dev = st.st_dev
    for root, dirs, files in os.walk(path, onerror=lambda _: None):
        keep = []
        for name in dirs + files:
            try:
                s = os.lstat(os.path.join(root, name))
            except OSError:
                continue
            if s.st_dev != dev:
                continue
            if stat.S_ISDIR(s.st_mode):
                if name in dirs:
                    keep.append(name)
            else:
                total += s.st_size
        dirs[:] = keep
    return total


def orphans(store, used):
    """Yield the orphaned paths under store, given the set of used paths."""
    parents = set()
    for p in used:
        d = os.path.dirname(p)
        while d != p and len(d) >= len(store):
            parents.add(d)
            p, d = d, os.path.dirname(d)

    def covered(path):
        p = path
        while len(p) > len(store):
            if p in used:
                return True
            p = os.path.dirname(p)
        return False

    stack = [store]
    while stack:
        d = stack.pop()
        try:
            names = sorted(os.listdir(d))
        except OSError as e:
            print(f"persist-orphans: cannot read {d}: {e.strerror}", file=sys.stderr)
            continue
        for name in names:
            path = os.path.join(d, name)
            if d == store and name == ".zfs":
                continue
            if covered(path):
                continue
            if path in parents and os.path.isdir(path) and not os.path.islink(path):
                stack.append(path)
                continue
            yield path


def human(n):
    for unit in ("B", "K", "M", "G", "T"):
        if n < 1024 or unit == "T":
            return f"{n:.1f}{unit}" if unit != "B" else f"{n}B"
        n /= 1024


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "--manifest", required=True, help="the host's persist manifest (JSON)"
    )
    ap.add_argument(
        "--no-size", action="store_true", help="skip sizing (fast on large orphans)"
    )
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument(
        "stores", nargs="*", help="limit to these stores (default: all in the manifest)"
    )
    args = ap.parse_args()

    used = load(args.manifest)
    stores = [s.rstrip("/") for s in args.stores] or sorted(used)
    unknown = [s for s in stores if s not in used]
    if unknown:
        ap.error(f"not a store in the manifest: {' '.join(unknown)}")

    rows = []
    for store in stores:
        if not os.path.ismount(store):
            print(
                f"persist-orphans: warning: {store} is not a mount point",
                file=sys.stderr,
            )
        for path in orphans(store, used[store]):
            rows.append(
                {"path": path, "bytes": None if args.no_size else apparent_size(path)}
            )

    if args.json:
        json.dump(rows, sys.stdout, indent=2)
        print()
        return 0
    if not args.no_size:
        rows.sort(key=lambda r: r["bytes"], reverse=True)
    for r in rows:
        size = "" if r["bytes"] is None else f"{human(r['bytes']):>8}  "
        print(f"{size}{r['path']}")
    if not args.no_size:
        total = sum(r["bytes"] for r in rows)
        print(f"{len(rows)} orphaned paths, {human(total)}", file=sys.stderr)
    else:
        print(f"{len(rows)} orphaned paths", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
