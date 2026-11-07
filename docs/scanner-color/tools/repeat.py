"""Scan-to-scan repeatability of a card read several times: the per-patch spread of the device
RGB values across `.ti3` files, and their mean as a new `.ti3` (reference XYZ unchanged).

usage: repeat.py out-mean.ti3 scan1.ti3 scan2.ti3 [...]
"""

import sys
from pathlib import Path

out, files = sys.argv[1], sys.argv[2:]
docs = [Path(f).read_text().split("\n") for f in files]
fields = next(line for line in docs[0] if line.startswith("SAMPLE_ID")).split()
ri = [fields.index(k) for k in ("RGB_R", "RGB_G", "RGB_B")]


def rows(lines):
    start, end = lines.index("BEGIN_DATA") + 1, lines.index("END_DATA")
    return {line.split()[0]: line.split() for line in lines[start:end] if line.strip()}


tables = [rows(d) for d in docs]
worst = []
mean_rows = {}
for pid, base in tables[0].items():
    vals = [[float(t[pid][i]) for i in ri] for t in tables]
    spread = max(max(v[c] for v in vals) - min(v[c] for v in vals) for c in range(3))
    worst.append((spread, pid))
    m = list(base)
    for c, i in enumerate(ri):
        m[i] = f"{sum(v[c] for v in vals) / len(vals):.5f}"
    mean_rows[pid] = m

worst.sort(reverse=True)
mean_spread = sum(s for s, _ in worst) / len(worst)
print(
    f"{len(files)} scans, device RGB on 0-100: mean per-patch spread {mean_spread:.2f}, "
    f"worst {worst[0][1]} {worst[0][0]:.2f}, next {worst[1][1]} {worst[1][0]:.2f}"
)

lines = list(docs[0])
start, end = lines.index("BEGIN_DATA") + 1, lines.index("END_DATA")
lines[start:end] = [
    " ".join(mean_rows[line.split()[0]]) + " "
    for line in lines[start:end]
    if line.strip()
]
Path(out).write_text("\n".join(lines))
