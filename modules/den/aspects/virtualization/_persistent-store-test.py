"""Unit tests for the persistent-store programs' pure pieces (docs/microvm-persistent-store.md).

Usage: python3 -I _persistent-store-test.py sweep=<_store-sweep.py> ...

Each case runs twice: against the real function, where it must pass, and against a mutant
that breaks the property the case guards, where it must fail. A case whose mutant passes
proves nothing, so that fails the run too.
"""

import importlib.util
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
