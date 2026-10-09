"""Unpack an OCI/docker `dir:` image into <out>/rootfs and <out>/env, inside the Nix sandbox.

umoci restores setuid/setgid bits, which the sandbox refuses. tarfile's "tar" filter clears
them; device nodes are skipped. Whiteouts are applied per layer, in order.

    python3 oci-unpack.py <image-dir> <out>
"""

import json
import os
import shutil
import sys
import tarfile

src, out = sys.argv[1:3]
root = os.path.join(out, "rootfs")
os.makedirs(root)
with open(os.path.join(src, "manifest.json")) as f:
    manifest = json.load(f)


def blob(digest):
    return os.path.join(src, digest.split(":", 1)[1])


def remove(path):
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path)
    elif os.path.lexists(path):
        os.remove(path)


for layer in manifest["layers"]:
    with tarfile.open(blob(layer["digest"]), "r:*") as tar:
        members = tar.getmembers()
        keep = []
        for m in members:
            parent, base = os.path.split(m.name)
            if base == ".wh..wh..opq":
                d = os.path.join(root, parent)
                if os.path.isdir(d):
                    for e in os.listdir(d):
                        remove(os.path.join(d, e))
            elif base.startswith(".wh."):
                remove(os.path.join(root, parent, base[4:]))
            elif m.isdev() or m.isfifo():
                continue
            else:
                if os.path.lexists(os.path.join(root, m.name)) and not (
                    m.isdir() and os.path.isdir(os.path.join(root, m.name))
                ):
                    remove(os.path.join(root, m.name))
                keep.append(m)
        tar.extractall(root, members=keep, filter="tar")
    # A read-only directory from one layer would block the next layer's writes.
    for d, dirs, _ in os.walk(root):
        for x in dirs:
            p = os.path.join(d, x)
            if not os.path.islink(p):
                os.chmod(p, os.stat(p).st_mode | 0o700)

with open(blob(manifest["config"]["digest"])) as f:
    config = json.load(f)
with open(os.path.join(out, "env"), "w") as f:
    f.write("".join(e + "\n" for e in config["config"].get("Env", [])))
