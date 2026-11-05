"""Project managed TOML keys into a mutable file: lens-toml TARGET MANAGED_JSON.

Every leaf of MANAGED_JSON (a scalar, an array, or an array of tables) is set in
TARGET; tables are walked, never replaced, so keys beside them survive. Leaves
applied last time (TARGET's sibling .<name>.hm-lens) and since dropped from
MANAGED_JSON are removed, and a table they leave empty goes with them.
"""

import json
import os
import shutil
import sys
import tempfile

import tomlkit


def leaves(d, prefix=()):
    for k, v in d.items():
        if isinstance(v, dict):
            yield from leaves(v, prefix + (k,))
        else:
            yield prefix + (k,), v


def table_at(doc, path):
    t = doc
    for k in path:
        if k not in t:
            t[k] = tomlkit.table(is_super_table=True)
        t = t[k]
    return t


def remove(doc, path):
    chain = [doc]
    for k in path[:-1]:
        if not isinstance(chain[-1], dict) or k not in chain[-1]:
            return
        chain.append(chain[-1][k])
    if isinstance(chain[-1], dict) and path[-1] in chain[-1]:
        del chain[-1][path[-1]]
    for i in range(len(chain) - 1, 0, -1):
        if len(chain[i]) == 0:
            del chain[i - 1][path[i - 1]]


def main():
    target, managed_json = sys.argv[1:]
    state = os.path.join(
        os.path.dirname(target), "." + os.path.basename(target) + ".hm-lens"
    )
    os.makedirs(os.path.dirname(target), exist_ok=True)
    # A store symlink left by a previous owner of this path becomes a plain file.
    if os.path.islink(target):
        real = os.path.realpath(target)
        os.unlink(target)
        shutil.copyfile(real, target)
        os.chmod(target, 0o600)

    try:
        with open(target) as f:
            doc = tomlkit.parse(f.read())
    except FileNotFoundError:
        doc = tomlkit.document()
    except Exception as e:  # noqa: BLE001
        print(f"lens-files: {target} does not parse; left unchanged: {e}", file=sys.stderr)
        return

    with open(managed_json) as f:
        managed = dict(leaves(json.load(f)))
    try:
        with open(state) as f:
            before = {tuple(p) for p in json.load(f)}
    except FileNotFoundError:
        before = set()

    for path in sorted(before - managed.keys(), key=len, reverse=True):
        remove(doc, path)
    for path, value in managed.items():
        table_at(doc, path[:-1])[path[-1]] = value

    out = tomlkit.dumps(doc)
    tomlkit.parse(out)  # never write what does not read back
    mode = os.stat(target).st_mode & 0o777 if os.path.exists(target) else 0o600
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(target))
    with os.fdopen(fd, "w") as f:
        f.write(out)
    os.chmod(tmp, mode)
    os.replace(tmp, target)
    with open(state, "w") as f:
        json.dump(sorted(managed), f)


if __name__ == "__main__":
    main()
