"""Unit tests for the persistent-store programs' pure pieces (docs/microvm-persistent-store.md).

Usage: python3 -I _persistent-store-test.py sweep=<_store-sweep.py> zvol=<_state-zvol.py> \
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


def _shrink_unchecked(real):
    return lambda held, wanted: None


@case("imp", "check_shrink", _shrink_unchecked)
def t_import_refuses_empty_or_collapsing_export(check_shrink):
    held = {f"{i:032d}-p" for i in range(100)}
    check_shrink(held, held)  # unchanged: fine
    check_shrink(held, set(list(held)[:20]))  # drops 80%: allowed
    check_shrink(set(), {"x"})  # first export: fine
    for wanted in (set(), set(list(held)[:5])):  # empty; drops 95%
        try:
            check_shrink(held, wanted)
        except Exception:  # noqa: BLE001
            continue
        raise AssertionError(f"accepted a collapse to {len(wanted)} of {len(held)}")


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
    def f(exchange_dir, max_paths):
        p = os.path.join(exchange_dir, "store-roots")
        if not os.path.exists(p):
            return real(exchange_dir, max_paths)
        with open(p, "rb") as fh:
            return fh.read()

    return f


@case("imp", "read_export", _read_follows)
def t_import_open_refuses_guest_tricks(read_export):
    import signal
    import tempfile

    def rejected(exchange, cap=10):
        try:
            read_export(exchange, cap)
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
            ("symlink", lambda s: os.symlink(secret, os.path.join(s, "store-roots"))),
            ("fifo", lambda s: os.mkfifo(os.path.join(s, "store-roots"))),
            ("dir-symlink", None),
            ("oversize", lambda s: open(os.path.join(s, "store-roots"), "w").write("x" * 2561)),
        ]:
            exchange = os.path.join(d, name)
            if make is None:
                real_dir = os.path.join(d, "real-" + name)
                os.makedirs(real_dir)
                with open(os.path.join(real_dir, "store-roots"), "w") as fh:
                    fh.write(GOOD + "\n")
                os.symlink(real_dir, exchange)
            else:
                os.makedirs(exchange)
                make(exchange)
            signal.alarm(2)
            try:
                assert rejected(exchange), name
            finally:
                signal.alarm(0)
        ok = os.path.join(d, "ok")
        os.makedirs(ok)
        with open(os.path.join(ok, "store-roots"), "w") as fh:
            fh.write(GOOD + "\n")
        assert read_export(ok, 10) == (GOOD + "\n").encode()
        # No export yet (no file, or no exchange directory): not a rejection.
        for missing in (os.path.join(d, "empty"), os.path.join(d, "absent")):
            if missing.endswith("empty"):
                os.makedirs(missing)
            try:
                read_export(missing, 10)
            except Exception as e:  # noqa: BLE001
                assert type(e).__name__ == "NoExport", (missing, e)
            else:
                raise AssertionError(f"read {missing}")


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


# --- zvol state (§2.10): format, grow, migrate, leaked zvols, backup drop ------------------


def _format_absent_is_pending(real):
    return lambda exists, formatted: real(exists, "pending" if formatted is None else formatted)


@case("zvol", "format_action", _format_absent_is_pending)
def t_format_only_in_creating_run(format_action):
    assert format_action(False, None) == "create"
    assert format_action(True, "pending") == "format"
    assert format_action(True, "1") == "ok"
    # An existing zvol without the property, or with any other value, is never formatted.
    assert format_action(True, None) == "refuse"
    assert format_action(True, "0") == "refuse"
    assert format_action(True, "yes") == "refuse"


def _grow_shrinks(real):
    return lambda have, want: "grow" if want != have else "ok"


@case("zvol", "grow_action", _grow_shrinks)
def t_grow_only(grow_action):
    assert grow_action(1 << 30, 2 << 30) == "grow"
    assert grow_action(1 << 30, 1 << 30) == "ok"
    assert grow_action(2 << 30, 1 << 30) == "refuse"


def _migrate_ignores_tmp(real):
    return lambda state, tmp, pre, migrated: real(state, "absent", pre, migrated)


@case("zvol", "migrate_action", _migrate_ignores_tmp)
def t_migrate_state_machine(migrate_action):
    A, D, F, O = "absent", "dir", "file", "other"
    table = {
        # (stateDir, temporary tombstone, .pre-zvol, migrated) -> step
        (A, A, A, False): "fresh",  # first backend is zvol
        (A, F, A, False): "fresh",  # crashed before the tombstone's rename
        (D, A, A, False): "tombstone",
        (D, F, A, False): "tombstone",  # crashed before the exchange
        (F, D, A, False): "rename",  # crashed after the exchange
        (F, A, D, False): "copy",  # crashed after the rename, or during the copy
        (F, A, A, False): "mark",  # zvol first, crashed before marking
        (F, A, D, True): "done",
        (F, A, A, True): "done",
        (D, A, A, True): "error",  # a live directory beside a migrated zvol
        (A, A, A, True): "error",
        (A, A, D, False): "error",
        (D, A, D, False): "error",
        (D, D, A, False): "error",
        (F, D, D, False): "error",
        (F, F, A, False): "error",
        (O, A, A, False): "error",
        (F, A, F, False): "error",
        (F, D, A, True): "error",
    }
    for k, want in table.items():
        assert migrate_action(*k) == want, (k, migrate_action(*k), want)


P = "zroot/local/microvms"


def _classify_virtiofs_unprotected(real):
    return lambda zvols, parent, zvol_guests, configured, destroy, busy: real(
        zvols, parent, zvol_guests, set(zvol_guests), destroy, busy
    )


@case("zvol", "classify_zvols", _classify_virtiofs_unprotected)
def t_zvols_refused_rollback_never_destroyed(classify_zvols):
    zvols = {
        f"{P}/dev-persist": True,  # zvol guest
        f"{P}/old-persist": True,  # guest set back to virtiofs: a refused rollback
        f"{P}/old-cache": False,  # same guest, never migrated: leaked, still not destroyable
        f"{P}/gone-persist": True,  # guest removed
    }
    every = set(zvols)
    leaked, destroy = classify_zvols(zvols, P, {"dev"}, {"dev", "old"}, every, set())
    assert leaked == [f"{P}/gone-persist", f"{P}/old-cache"], leaked
    assert destroy == [f"{P}/gone-persist"], destroy


def _classify_ignores_busy(real):
    return lambda zvols, parent, zvol_guests, configured, destroy, busy: real(
        zvols, parent, zvol_guests, configured, destroy, set()
    )


@case("zvol", "classify_zvols", _classify_ignores_busy)
def t_zvols_destroy_only_listed_and_idle(classify_zvols):
    zvols = {f"{P}/a-persist": False, f"{P}/b-persist": False, f"{P}/c-persist": False}
    leaked, destroy = classify_zvols(
        zvols, P, set(), set(), {f"{P}/a-persist", f"{P}/b-persist"}, {f"{P}/b-persist"}
    )
    assert leaked == sorted(zvols), leaked
    assert destroy == [f"{P}/a-persist"], destroy


def _drop_ignores_backend(real):
    return lambda backend, migrated: real("zvol", migrated)


@case("zvol", "drop_backup_ok", _drop_ignores_backend)
def t_drop_backup_needs_zvol_and_every_migrated(drop_backup_ok):
    assert drop_backup_ok("zvol", [True, True])
    assert not drop_backup_ok("zvol", [True, False])
    assert not drop_backup_ok("zvol", [])
    assert not drop_backup_ok("virtiofs", [True, True])


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
