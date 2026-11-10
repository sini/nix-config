"""Unit tests for the persistent-store programs' pure pieces (docs/microvm-persistent-store.md).

Usage: python3 -I _persistent-store-test.py sweep=<_store-sweep.py> \
         imp=<_store-roots-import.py> guest=<_store-guest.py>

Each case runs twice: against the real function, where it must pass, and against a mutant
that breaks the property the case guards, where it must fail. A case whose mutant passes
proves nothing, so that fails the run too.
"""

import importlib.util
import os
import sys


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


CASES = []


def case(module, fn, mutant):
    """Register a test of module.fn; `mutant(real)` returns the broken variant."""

    def wrap(test):
        CASES.append((module, fn, mutant, test))
        return test

    return wrap


# --- sweep: the keep-set computation -------------------------------------------------


def _sweep_ignores_keep(real):
    return lambda images, root_dirs, keep_images, keep_roots, configured, open_images, active: real(
        images, root_dirs, set(), set(), configured, open_images, active
    )


@case("sweep", "plan", _sweep_ignores_keep)
def t_sweep_keeps_named(plan):
    imgs, roots = plan(
        ["/s/a-tmp.img", "/s/a-nix-store-e0.img", "/s/a-nix-rw-store.img"],
        ["a", "gone"],
        {"/s/a-tmp.img", "/s/a-nix-store-e0.img"},
        {"a"},
        {"a"},
        set(),
        set(),
    )
    assert imgs == ["/s/a-nix-rw-store.img"], imgs
    assert roots == ["gone"], roots


def _sweep_ignores_open(real):
    return lambda images, root_dirs, keep_images, keep_roots, configured, open_images, active: real(
        images, root_dirs, keep_images, keep_roots, configured, set(), active
    )


@case("sweep", "plan", _sweep_ignores_open)
def t_sweep_skips_open_image(plan):
    imgs, _ = plan(["/s/old.img"], [], set(), set(), set(), {"/s/old.img"}, set())
    assert imgs == [], imgs


def _sweep_ignores_active(real):
    return lambda images, root_dirs, keep_images, keep_roots, configured, open_images, active: real(
        images, root_dirs, keep_images, keep_roots, configured, open_images, set()
    )


@case("sweep", "plan", _sweep_ignores_active)
def t_sweep_skips_running_unconfigured(plan):
    # "removed" left the config but still runs: kept. "off" is configured with the
    # feature off and runs: swept anyway (§2.4).
    _, roots = plan([], ["removed", "off"], set(), set(), {"off"}, set(), {"removed", "off"})
    assert roots == ["off"], roots


# --- import: the strict line parser and the link plan ---------------------------------

GOOD = "/nix/store/" + "a" * 32 + "-hello-2.12"
GOOD2 = "/nix/store/" + "b" * 32 + "-world"


def _reject(parse, data, cap):
    try:
        parse(data, cap)
    except Exception as e:  # noqa: BLE001
        return e
    raise AssertionError(f"accepted {data!r}")


def _parse_lenient(real):
    def parse(data, cap):
        lines = [x for x in data.decode().split("\n") if x.startswith("/nix/store/")]
        return real("\n".join(lines).encode(), cap)

    return parse


@case("imp", "parse", _parse_lenient)
def t_import_rejects_bad_lines(parse):
    assert parse(f"{GOOD}\n{GOOD2}\n".encode(), 10) == [GOOD[11:], GOOD2[11:]]
    assert parse(b"", 10) == []
    for bad in [
        "/etc/shadow",
        "/nix/store/" + "e" * 32 + "-x",  # 'e' is outside Nix's base-32 alphabet
        "/nix/store/" + "a" * 32 + "-../../etc",
        GOOD + "/bin",
        "",
    ]:
        _reject(parse, f"{GOOD}\n{bad}\n".encode(), 10)


def _parse_uncapped(real):
    return lambda data, cap: real(data, 10**9)


@case("imp", "parse", _parse_uncapped)
def t_import_cap_counts_paths(parse):
    assert len(parse(f"{GOOD}\n{GOOD2}\n".encode(), 2)) == 2
    _reject(parse, f"{GOOD}\n{GOOD2}\n".encode(), 1)


def _links_no_remove(real):
    return lambda existing, wanted, store_dir: (real(existing, wanted, store_dir)[0], [])


@case("imp", "plan_links", _links_no_remove)
def t_import_link_plan(plan_links):
    add, remove = plan_links(
        {"a-x": "/nix/store/a-x", "b-y": "/nix/store/b-y", "c-z": "/elsewhere"},
        {"a-x", "c-z", "d-w"},
        "/nix/store",
    )
    assert add == ["c-z", "d-w"], add
    assert remove == ["b-y"], remove


def _read_follows(real):
    def f(state_dir, max_paths):
        p = os.path.join(state_dir, ".microvm-store", "roots")
        if not os.path.exists(p):
            return real(state_dir, max_paths)
        with open(p, "rb") as fh:
            return fh.read()

    return f


@case("imp", "read_export", _read_follows)
def t_import_open_refuses_guest_tricks(read_export):
    import signal
    import tempfile

    def rejected(state, cap=10):
        try:
            read_export(state, cap)
        except Exception as e:  # noqa: BLE001
            return type(e).__name__ == "Rejected"
        return False

    # A FIFO must be refused, not block: a blocked read fails the case by timeout.
    signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("blocked")))
    with tempfile.TemporaryDirectory() as d:
        secret = os.path.join(d, "secret")
        with open(secret, "w") as fh:
            fh.write(GOOD + "\n")
        for name, make in [
            ("symlink", lambda s: os.symlink(secret, os.path.join(s, ".microvm-store", "roots"))),
            ("fifo", lambda s: os.mkfifo(os.path.join(s, ".microvm-store", "roots"))),
            ("dir-symlink", None),
            ("oversize", lambda s: open(os.path.join(s, ".microvm-store", "roots"), "w").write("x" * 2561)),
        ]:
            state = os.path.join(d, name)
            os.makedirs(state)
            if make is None:
                real_dir = os.path.join(d, "real-" + name)
                os.makedirs(real_dir)
                with open(os.path.join(real_dir, "roots"), "w") as fh:
                    fh.write(GOOD + "\n")
                os.symlink(real_dir, os.path.join(state, ".microvm-store"))
            else:
                os.makedirs(os.path.join(state, ".microvm-store"))
                make(state)
            signal.alarm(2)
            try:
                assert rejected(state), name
            finally:
                signal.alarm(0)
        ok = os.path.join(d, "ok")
        os.makedirs(os.path.join(ok, ".microvm-store"))
        with open(os.path.join(ok, ".microvm-store", "roots"), "w") as fh:
            fh.write(GOOD + "\n")
        assert read_export(ok, 10) == (GOOD + "\n").encode()


# --- guest: root lines, E, the mount check ---------------------------------------------


def _root_line_keeps_quotes(real):
    def f(line):
        link, sep, target = line.rpartition(" -> ")
        return link, target

    return f


@case("guest", "parse_root_line", _root_line_keeps_quotes)
def t_root_line(parse_root_line):
    assert parse_root_line(f'"/home/u/.direnv/flake-profile" -> {GOOD}') == (
        "/home/u/.direnv/flake-profile",
        GOOD,
    )
    assert parse_root_line(f'"/a \\"q\\" -> b" -> {GOOD}') == ('/a "q" -> b', GOOD)
    assert parse_root_line(f"/proc/1/maps -> {GOOD}") == ("/proc/1/maps", GOOD)


def _export_keeps_upper(real):
    return lambda closure, upper_names: sorted(closure)


@case("guest", "export_set", _export_keeps_upper)
def t_export_set(export_set):
    assert export_set({GOOD, GOOD2}, {GOOD2[11:]}) == [GOOD]


MOUNTS = (
    "rootfs / tmpfs rw 0 0\n"
    "ro-store /sysroot/nix/.ro-store virtiofs ro 0 0\n"
    "overlay /nix/store overlay rw,lowerdir=/sysroot/nix/.ro-store,"
    "upperdir=/sysroot/nix/.rw-store/store,workdir=/sysroot/nix/.rw-store/work 0 0\n"
)


def _mount_any_overlay(real):
    return lambda text, ro, upper: real(text, "", "")


@case("guest", "check_mount", _mount_any_overlay)
def t_check_mount(check_mount):
    assert check_mount(MOUNTS, "/nix/.ro-store", "/nix/.rw-store/store")
    wrong = MOUNTS.replace("/sysroot/nix/.rw-store/store", "/tmp/other")
    assert not check_mount(wrong, "/nix/.ro-store", "/nix/.rw-store/store")
    # A later mount over /nix/store is the current one.
    stacked = MOUNTS + "store /nix/store virtiofs ro 0 0\n"
    assert not check_mount(stacked, "/nix/.ro-store", "/nix/.rw-store/store")


# --- reconcile: topo sort, classification, counters ------------------------------------


def _topo_alpha(real):
    return lambda paths, refs: sorted(paths)


@case("guest", "topo_order", _topo_alpha)
def t_topo_references_first(topo_order):
    # a -> b -> c (a chain of depth 2), plus a self-reference and a ref outside the set.
    refs = {"a": ["b", "a", "z"], "b": ["c"], "c": []}
    assert topo_order({"a", "b", "c"}, refs) == ["c", "b", "a"]


def _classify_peer_blocks(real):
    def f(results):
        if any(a == "error" for _, a in results):
            return "unknown"
        return real(results)

    return f


@case("guest", "classify", _classify_peer_blocks)
def t_classify_offline_peer_is_absent(classify):
    r = [
        ("http://bitstream:16893", "error"),
        ("https://cache.nixos.org/", "absent"),
        ("https://nix-community.cachix.org", "absent"),
    ]
    assert classify(r) == "unsubstitutable", classify(r)
    assert classify(r + [("https://attic.json64.dev/ci", "error")]) == "unknown"
    assert classify(r + [("https://attic.json64.dev/ci", "present")]) == "present"


def _classify_no_public(real):
    def f(results):
        if all(a in ("absent", "error") for _, a in results) and any(
            a == "absent" for _, a in results
        ):
            return "unsubstitutable"
        return real(results)

    return f


@case("guest", "classify", _classify_no_public)
def t_classify_needs_a_public_cache(classify):
    assert classify([("http://cortex:16893", "absent")]) == "unknown"
    assert classify([("https://attic.json64.dev/ci", "absent")]) == "unknown"
    assert classify([]) == "unknown"


def _counter_in_memory(real):
    counts = {}

    def f(state_dir, base):
        counts[base] = counts.get(base, 0) + 1
        return counts[base]

    f.reset = counts.clear
    return f


@case("guest", "bump_counter", _counter_in_memory)
def t_counter_persists(bump_counter):
    import tempfile

    with tempfile.TemporaryDirectory() as d:
        state = os.path.join(d, "reconcile")
        assert bump_counter(state, "p") == 1
        assert bump_counter(state, "p") == 2
        # A guest restart between runs: only the volume carries the count.
        getattr(bump_counter, "reset", lambda: None)()
        assert bump_counter(state, "p") == 3
        assert bump_counter(state, "q") == 1


def main(argv):
    mods = {}
    for a in argv:
        name, path = a.split("=", 1)
        mods[name] = load(name, path)
    failed = 0
    ran = 0
    for module, fn, mutant, test in CASES:
        if module not in mods:
            continue
        ran += 1
        real = getattr(mods[module], fn)
        try:
            test(real)
        except Exception as e:  # noqa: BLE001
            failed += 1
            print(f"FAIL {test.__name__}: {e!r}")
            continue
        try:
            test(mutant(real))
        except Exception:  # noqa: BLE001
            print(f"ok   {test.__name__} (negative control fails)")
            continue
        failed += 1
        print(f"FAIL {test.__name__}: negative control passed, so the case proves nothing")
    print(f"{ran} cases, {failed} failed")
    if ran == 0 or failed:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
