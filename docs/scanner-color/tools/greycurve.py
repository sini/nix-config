"""Grey-only calibration from a ColorChecker .ti3: per-channel tone curves that send each of
the six grey patches (D01..D06) to the sRGB value of its reference lightness, as a neutral.
Nothing else in the card is used, so the scanner's own colour is left as it is; only tone
and grey balance change. Writes a 256x1 PPM colour-lookup image for `magick -clut`.

usage: greycurve.py target.ti3 out.ppm
"""

import sys
from itertools import pairwise
from pathlib import Path

ti3, out = sys.argv[1], sys.argv[2]
lines = Path(ti3).read_text().split("\n")
fields = next(l for l in lines if l.startswith("SAMPLE_ID")).split()
start, end = lines.index("BEGIN_DATA") + 1, lines.index("END_DATA")
rows = {l.split()[0]: l.split() for l in lines[start:end] if l.strip()}
ri = [fields.index(k) for k in ("RGB_R", "RGB_G", "RGB_B")]
yi = fields.index("XYZ_Y")


def srgb_encode(y):  # relative luminance 0..1 -> sRGB 0..1
    return 12.92 * y if y <= 0.0031308 else 1.055 * y ** (1 / 2.4) - 0.055


# Reference luminance of each grey, relative to the white patch, with the white patch at
# 0.96 (headroom, so real whites brighter than the card's white do not clip).
white_y = float(rows["D01"][yi])
points = []
for p in ("D06", "D05", "D04", "D03", "D02", "D01"):
    y = float(rows[p][yi]) / white_y * 0.96
    points.append(([float(rows[p][i]) / 100 for i in ri], srgb_encode(y)))

# Anchor the ends: device 0 -> 0 and device 1 -> 1, so the curve is defined everywhere.
curves = []
for c in range(3):
    xs = [0.0] + [d[c] for d, _ in points] + [1.0]
    ys = [0.0] + [t for _, t in points] + [1.0]
    assert all(b > a for a, b in pairwise(xs)), f"channel {c}: greys not monotonic"
    lut = []
    for i in range(256):
        x = i / 255
        k = next(j for j in range(len(xs) - 1) if xs[j] <= x <= xs[j + 1])
        t = (x - xs[k]) / (xs[k + 1] - xs[k])
        lut.append(round(255 * (ys[k] + t * (ys[k + 1] - ys[k]))))
    curves.append(lut)

with open(out, "wb") as f:
    f.write(b"P6\n256 1\n255\n")
    f.write(
        bytes(v for i in range(256) for v in (curves[0][i], curves[1][i], curves[2][i]))
    )
for p, (d, t) in zip(("D06", "D05", "D04", "D03", "D02", "D01"), points):
    print(f"{p}: device {[round(v, 3) for v in d]} -> sRGB {t:.3f}")
