"""Tone-preserving reference for a ColorChecker .ti3: each patch keeps the lightness the raw
scan already has (its RGB read as sRGB, which is how every viewer shows it today) and takes
its hue and chroma from the chart's reference. A profile fitted to this corrects colour only;
the scanner's tone curve (its contrast and black) stays as it is.

usage: tone.py in.ti3 out.ti3
"""

import sys
from pathlib import Path

# sRGB primaries adapted to D50 (the ICC PCS), and the D50 white.
M = [
    [0.4360747, 0.3850649, 0.1430804],
    [0.2225045, 0.7168786, 0.0606169],
    [0.0139322, 0.0971045, 0.7141733],
]
WHITE = (96.422, 100.0, 82.521)


def srgb_to_xyz(rgb):
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return [100 * sum(M[r][k] * lin[k] for k in range(3)) for r in range(3)]


def f(t):
    return t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116


def finv(t):
    return t**3 if t**3 > 216 / 24389 else (116 * t - 16) * 27 / 24389


def xyz_to_lab(xyz):
    fx, fy, fz = (f(v / w) for v, w in zip(xyz, WHITE))
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def lab_to_xyz(lab):
    L, a, b = lab
    fy = (L + 16) / 116
    return [w * finv(t) for w, t in zip(WHITE, (fy + a / 500, fy, fy - b / 200))]


src, dst = sys.argv[1], sys.argv[2]
lines = Path(src).read_text().split("\n")
start, end = lines.index("BEGIN_DATA") + 1, lines.index("END_DATA")
fields = next(l for l in lines if l.startswith("SAMPLE_ID")).split()
xi = [fields.index(k) for k in ("XYZ_X", "XYZ_Y", "XYZ_Z")]
ri = [fields.index(k) for k in ("RGB_R", "RGB_G", "RGB_B")]

out = lines[:start]
for l in lines[start:end]:
    if not l.strip():
        out.append(l)
        continue
    v = l.split()
    ref = xyz_to_lab([float(v[i]) for i in xi])
    raw = xyz_to_lab(srgb_to_xyz([float(v[i]) / 100 for i in ri]))
    new = (raw[0], ref[1], ref[2])
    for i, x in zip(xi, lab_to_xyz(new)):
        v[i] = f"{x:.5f}"
    out.append(" ".join(v) + " ")
    print(
        f"{v[0]}: L {ref[0]:5.1f} -> {raw[0]:5.1f}   a,b ({ref[1]:6.1f},{ref[2]:6.1f})  raw a,b ({raw[1]:6.1f},{raw[2]:6.1f})"
    )
out += lines[end:]
Path(dst).write_text("\n".join(out))
