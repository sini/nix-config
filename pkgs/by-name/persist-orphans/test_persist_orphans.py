"""Self-check for persist-orphans: one store tree covering every classification."""

import json
import os
import subprocess
import sys
import tempfile

tool = sys.argv[1]

with tempfile.TemporaryDirectory() as t:
    store = os.path.join(t, "persist")

    def mk(rel, data=None):
        p = os.path.join(store, rel)
        if data is None:
            os.makedirs(p, exist_ok=True)
        else:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "wb") as f:
                f.write(data if isinstance(data, bytes) else data.encode())

    mk("home/u/.ssh/id")  # entry (directory): used
    mk("home/u/.ssh/id/key", "k")  # inside an entry: used
    mk("home/u/.config/gh/hosts.yml", "t")  # entry (file): used
    mk("home/u/.config/gh/stale.yml", "x")  # sibling of a file entry: orphan
    mk(
        "home/u/.config/old-app/db", os.urandom(1 << 16)
    )  # under a parent, unused: orphan
    mk("home/u/gone")  # unused at the user level: orphan
    mk("etc/machine-id", "m")  # entry (file) at the top: used
    mk("microvms/vm1/disk", "d")  # inside a direct path: used
    mk("microvms/vm2/disk", "d")  # beside a direct path: orphan
    mk("var/lib/removed-service/state", "s")  # unused system tree: reported as "var"
    mk(".zfs/snapshot")  # zfs control dir: skipped
    os.symlink(
        "/nowhere", os.path.join(store, "home/u/dangling")
    )  # a link: orphan, not followed

    manifest = os.path.join(t, "m.json")
    with open(manifest, "w") as f:
        json.dump(
            {
                "entries": [
                    {"live": "/home/u/.ssh", "store": store, "kind": "directory"},
                    {
                        "live": "/home/u/.config/gh/hosts.yml",
                        "store": store,
                        "kind": "file",
                    },
                    {"live": "/etc/machine-id", "store": store, "kind": "file"},
                ],
                "directPaths": [
                    os.path.join(store, "microvms/vm1"),
                    "/elsewhere/ignored",
                ],
            },
            f,
        )

    out = subprocess.run(
        [tool, "--manifest", manifest, "--json"],
        capture_output=True,
        text=True,
        check=True,
    )
    got = {
        os.path.relpath(r["path"], store): r["bytes"] for r in json.loads(out.stdout)
    }
    want = {
        "home/u/.config/gh/stale.yml",
        "home/u/.config/old-app",
        "home/u/gone",
        "home/u/dangling",
        "microvms/vm2",
        "var",  # nothing beneath it is used, so the top-most unused path is reported
    }
    assert set(got) == want, f"orphans: got {sorted(got)}, want {sorted(want)}"
    assert got["home/u/.config/old-app"] == 1 << 16, got
    assert got["var"] == 1 and got["home/u/gone"] == 0, got
    assert "home/u/.ssh" not in got and "etc" not in got, got

    bad = subprocess.run(
        [tool, "--manifest", manifest, "/not-a-store"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert bad.returncode != 0 and "not a store" in bad.stderr, bad.stderr

print("persist-orphans: self-check passed")
