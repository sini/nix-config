"""nix-persistent-store: a persistent-store guest's root export and reconcile.

docs/microvm-persistent-store.md §2.3 (export) and §2.6 (reconcile). Every Nix call goes
through the guest's daemon (store = daemon); the host's validity is asked of the lower
store directly, over the vsock socket.
"""

import argparse
import json
import os
import re
import stat
import subprocess
import sys

CHUNK = 2000
FRESH = ["--option", "narinfo-cache-negative-ttl", "0"]
BASE_RE = re.compile(r"^[0-9a-df-np-sv-z]{32}-[0-9A-Za-z+\-._?=]{1,211}$")
# A LAN peer's nix-serve (core.nix.remote-build-client): a best-effort mirror of a store
# its host collects, so an unreachable one counts as absent (§2.6 step 4).
PEER_RE = re.compile(r"^http://[^/:]+:16893/?$")
PUBLIC_RE = re.compile(r"^https://(cache\.nixos\.org|[^/]+\.cachix\.org)/?$")
GIVE_UP_AFTER = 3


class Failed(Exception):
    pass


# --- pure pieces ---------------------------------------------------------------------


def parse_root_line(line):
    """`<link> -> <target>` (the link quoted by --print-roots, bare by --query --roots)."""
    link, sep, target = line.rpartition(" -> ")
    if not sep:
        raise ValueError(f"not a root line: {line!r}")
    if len(link) >= 2 and link[0] == '"' and link[-1] == '"':
        link = re.sub(r"\\(.)", r"\1", link[1:-1])
    return link, target


def export_set(closure, upper_names):
    """E: the closure members with no entry in the upper layer, sorted."""
    return sorted(p for p in closure if os.path.basename(p) not in upper_names)


def check_mount(mounts_text, ro_suffix, upper_suffix):
    """The last /nix/store mount is an overlay over the expected lower and upper dirs."""
    last = None
    for line in mounts_text.splitlines():
        f = line.split()
        if len(f) >= 4 and f[1] == "/nix/store":
            last = f
    if last is None or last[2] != "overlay":
        return False
    opts = dict(o.split("=", 1) for o in last[3].split(",") if "=" in o)
    return opts.get("lowerdir", "").endswith(ro_suffix) and opts.get(
        "upperdir", ""
    ).endswith(upper_suffix)


def topo_order(paths, refs):
    """Paths ordered references first; refs maps a path to the paths it references."""
    todo = set(paths)
    deps = {p: {r for r in refs.get(p, ()) if r in todo and r != p} for p in todo}
    order = []
    while todo:
        ready = sorted(p for p in todo if not deps[p] & todo)
        if not ready:
            raise Failed(f"reference cycle among {sorted(todo)}")
        order += ready
        todo -= set(ready)
    return order


def classify(results):
    """Substituter answers -> "present", "unsubstitutable" or "unknown".

    results: (url, answer) pairs, answer one of "present", "absent", "error". An erroring
    LAN peer counts as absent; an erroring other cache leaves the answer unknown. Giving up
    also needs a public cache among those that answered absent.
    """
    if any(a == "present" for _, a in results):
        return "present"
    if any(a == "error" and not PEER_RE.match(u) for u, a in results):
        return "unknown"
    if any(a == "absent" and PUBLIC_RE.match(u) for u, a in results):
        return "unsubstitutable"
    return "unknown"


def bump_counter(state_dir, base):
    """Count one more unsubstitutable run of `base`; the count persists in state_dir."""
    os.makedirs(state_dir, mode=0o755, exist_ok=True)
    p = os.path.join(state_dir, base)
    try:
        with open(p) as f:
            n = int(f.read().strip() or "0")
    except FileNotFoundError:
        n = 0
    n += 1
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        f.write(f"{n}\n")
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, p)
    return n


def prune_counters(state_dir, keep):
    """Drop the count of every path not in `keep` (a run that was not unsubstitutable)."""
    if not os.path.isdir(state_dir):
        return
    for name in os.listdir(state_dir):
        if name not in keep:
            os.unlink(os.path.join(state_dir, name))


# --- Nix -----------------------------------------------------------------------------


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, text=True, stdout=subprocess.PIPE, **kw).stdout


def chunks(xs):
    xs = sorted(xs)
    for i in range(0, len(xs), CHUNK):
        yield xs[i : i + CHUNK]


def invalid(paths, store=None):
    """The members of `paths` that `store` (default: the daemon) does not hold valid."""
    opt = ["--store", store] if store else []
    out = set()
    for c in chunks(paths):
        out |= set(run(["nix-store", *opt, "--check-validity", "--print-invalid", *c]).split())
    return out


def requisites(paths, include_outputs):
    flag = ["--include-outputs"] if include_outputs else []
    out = set()
    for c in chunks(paths):
        out |= set(run(["nix-store", "--query", "--requisites", *flag, *c]).split())
    return out


def upper_entries(upper):
    """Names in the upper layer that are store entries, not whiteouts."""
    names = set()
    with os.scandir(upper) as it:
        for e in it:
            if BASE_RE.match(e.name) and not stat.S_ISCHR(e.stat(follow_symlinks=False).st_mode):
                names.add(e.name)
    return names


def compute_export(a):
    store_dir = a.store_dir
    roots = set()
    for line in run(["nix-store", "--gc", "--print-roots"]).splitlines():
        _, target = parse_root_line(line)
        if target.startswith(store_dir + "/"):
            roots.add(target)
    roots -= invalid(roots)
    upper = upper_entries(a.upper)
    u = {f"{store_dir}/{n}" for n in upper}
    u -= invalid(u)
    closure = requisites(roots, True) | requisites(u, False)
    return export_set(closure, upper)


def cmd_export(a):
    e = compute_export(a)
    if len(e) > a.max_paths:
        raise Failed(f"{len(e)} paths exceed maxExportPaths={a.max_paths}; previous export kept")
    content = "".join(p + "\n" for p in e)
    d = os.path.dirname(a.out)
    os.makedirs(d, mode=0o755, exist_ok=True)
    try:
        with open(a.out) as f:
            if f.read() == content:
                print(f"{len(e)} paths, unchanged")
                return 0
    except FileNotFoundError:
        pass
    tmp = a.out + ".tmp"
    with open(tmp, "w") as f:
        f.write(content)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, a.out)
    print(f"{len(e)} paths, written")
    return 0


def substituters():
    return run(["nix", "config", "show", "substituters"]).split()


def answer(sub, path):
    r = subprocess.run(
        ["nix", "path-info", *FRESH, "--json", "--json-format", "1", "--store", sub, path],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if r.returncode != 0:
        return "error"
    try:
        info = json.loads(r.stdout)
    except ValueError:
        return "error"
    return "present" if any(v is not None for v in info.values()) else "absent"


def auto_roots_for(links, auto_dir):
    """gcroots/auto entries that are, or point at, one of `links`."""
    out = []
    if not os.path.isdir(auto_dir):
        return out
    for name in os.listdir(auto_dir):
        p = os.path.join(auto_dir, name)
        try:
            target = os.readlink(p)
        except OSError:
            continue
        if p in links or target in links:
            out.append(p)
    return out


def roots_of(path):
    return [parse_root_line(line) for line in run(["nix-store", "--query", "--roots", path]).splitlines()]


def cmd_reconcile(a):
    store_dir = a.store_dir
    fail = []

    # 0. the mount
    with open("/proc/self/mounts") as f:
        if not check_mount(f.read(), a.ro, a.upper):
            raise Failed(f"{store_dir} is not an overlay of {a.ro} and {a.upper}")

    # 1. whiteouts over store paths hide the host's copy
    scrubbed = 0
    with os.scandir(a.upper) as it:
        for e in it:
            if e.name != ".links" and stat.S_ISCHR(e.stat(follow_symlinks=False).st_mode):
                os.unlink(e.path)
                scrubbed += 1
    if scrubbed:
        print(f"scrubbed {scrubbed} whiteouts")
        run([a.remount_hook, store_dir])

    # 2. missing by validity: a row with no upper entry that the host does not hold valid
    rows = set(run(["nix", "path-info", "--all"]).split())
    upper = upper_entries(a.upper)
    host_invalid = invalid({r for r in rows if os.path.basename(r) not in upper}, a.lower)
    m = {r for r in rows if os.path.basename(r) not in upper and r in host_invalid}
    e = set(compute_export(a))
    d = m & e
    print(f"{len(rows)} rows, {len(m)} missing, {len(d)} depended on")

    # 3. repair by substitution only, references first
    refs = {p: run(["nix-store", "--query", "--references", p]).split() for p in d}
    for p in topo_order(d, refs):
        try:
            r = subprocess.run(
                ["nix-store", *FRESH, "--realise", "--repair", p], timeout=3600, check=False
            )
        except subprocess.TimeoutExpired:
            fail.append(f"repair of {p} timed out")
            continue
        print(f"repair {p}: exit {r.returncode}")

    # 4. give up on what no substituter has, after GIVE_UP_AFTER consecutive runs
    upper = upper_entries(a.upper)
    not_upper = {p for p in d if os.path.basename(p) not in upper}
    still = sorted(invalid(not_upper, a.lower))
    subs = substituters() if still else []
    counting, give_up = [], []
    for p in still:
        verdict = classify([(s, answer(s, p)) for s in subs])
        if verdict != "unsubstitutable":
            fail.append(f"{p} missing and not repaired ({verdict})")
            continue
        n = bump_counter(a.counters, os.path.basename(p))
        print(f"{p}: unsubstitutable, run {n} of {GIVE_UP_AFTER}")
        (give_up if n >= GIVE_UP_AFTER else counting).append(p)
    # A give-up that fails keeps its count, so the next run retries it.
    prune_counters(a.counters, {os.path.basename(p) for p in counting + give_up})

    if give_up:
        auto_dir = os.path.join(a.state_dir, "gcroots", "auto")
        for p in give_up:
            links = {link for link, _ in roots_of(p)}
            for r in auto_roots_for(links, auto_dir):
                print(f"giving up {p}: removing auto root {r} -> {os.readlink(r)}")
                os.unlink(r)
        run(["nix-store", "--gc"])
        for p in give_up:
            if invalid([p]):
                print(f"gave up {p}")
                continue
            holders = sorted(link for link, _ in roots_of(p))
            if holders:
                fail.append(f"{p} given up but still held by {holders}")

    if fail:
        raise Failed("; ".join(fail))
    if counting:
        print(f"{len(counting)} unsubstitutable paths still counting; verify deferred")
        return 0

    # 5. drop stale rows; a half-deleted host path outside E needs the guest GC first
    half = sorted(p for p in m - e if os.path.lexists(os.path.join(a.ro, os.path.basename(p))))
    if half:
        print(f"{len(half)} half-deleted host paths outside E; running the guest GC")
        run(["nix-store", "--gc"])
        survived = sorted(set(half) - invalid(half))
        if survived:
            raise Failed(f"half-deleted host paths survived the guest GC: {survived}")
    if m:
        # The ro-store share passes file handles, so a dentry cached before the host deleted
        # the path answers ESTALE, not ENOENT, and nix-store --verify aborts on it (measured
        # 2026-11-10: 1595 missing rows, "Stale file handle" every run). Dropping the
        # unused dentries makes the next lookup go to virtiofsd and see ENOENT.
        with open("/proc/sys/vm/drop_caches", "w") as f:
            f.write("2\n")
    run(["nix-store", "--verify"])
    return 0


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["export", "reconcile"])
    ap.add_argument("--store-dir", required=True)
    ap.add_argument("--state-dir", required=True)
    ap.add_argument("--upper", required=True)
    ap.add_argument("--ro", required=True)
    ap.add_argument("--lower", required=True)
    ap.add_argument("--remount-hook", required=True)
    ap.add_argument("--counters", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--max-paths", type=int, required=True)
    a = ap.parse_args(argv)
    try:
        return cmd_export(a) if a.command == "export" else cmd_reconcile(a)
    except (Failed, subprocess.CalledProcessError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
