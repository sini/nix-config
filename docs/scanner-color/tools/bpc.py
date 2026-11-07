"""Black-point-compensate a ColorChecker .ti3: remap the reference XYZ so the chart's black
patch (D06) becomes zero while its white patch (D01) keeps its value, per channel:

    XYZ' = (XYZ - XYZ_black) * XYZ_white / (XYZ_white - XYZ_black)

The scanner already stretches the chart's black to RGB 0 and its white to RGB 1 (its own
levels), so the profile must map RGB 0 to black, not to the patch's L*20 grey.
usage: bpc.py in.ti3 out.ti3
"""

import sys
from pathlib import Path

src, dst = sys.argv[1], sys.argv[2]
lines = Path(src).read_text().split("\n")
start = lines.index("BEGIN_DATA") + 1
end = lines.index("END_DATA")
fields = next(l for l in lines if l.startswith("SAMPLE_ID")).split()
ix = [fields.index(f) for f in ("XYZ_X", "XYZ_Y", "XYZ_Z")]

rows = {l.split()[0]: l.split() for l in lines[start:end] if l.strip()}
black = [float(rows["D06"][i]) for i in ix]
white = [float(rows["D01"][i]) for i in ix]

out = lines[:start]
for l in lines[start:end]:
    if not l.strip():
        out.append(l)
        continue
    v = l.split()
    for i, b, w in zip(ix, black, white):
        v[i] = f"{(float(v[i]) - b) * w / (w - b):.5f}"
    out.append(" ".join(v) + " ")
out += lines[end:]
Path(dst).write_text("\n".join(out))

check = {l.split()[0]: l.split() for l in out[start:end] if l.strip()}
print("D06 ->", [check["D06"][i] for i in ix], " D01 ->", [check["D01"][i] for i in ix])
