"""Mean Lab (pixels read as sRGB, D50) of rectangles in a PPM, for checking what colour a
region of the raw scan has. usage: sample.py image.ppm x,y,w,h[:label] ..."""

import sys
from pathlib import Path

M = [
    [0.4360747, 0.3850649, 0.1430804],
    [0.2225045, 0.7168786, 0.0606169],
    [0.0139322, 0.0971045, 0.7141733],
]
W = (0.96422, 1.0, 0.82521)


def lab(rgb):
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    xyz = [sum(M[r][k] * lin[k] for k in range(3)) for r in range(3)]
    f = [
        (v / w) ** (1 / 3) if v / w > 216 / 24389 else (24389 / 27 * v / w + 16) / 116
        for v, w in zip(xyz, W)
    ]
    return 116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])


data = Path(sys.argv[1]).read_bytes()
parts = data.split(maxsplit=4)
w, h, mx = int(parts[1]), int(parts[2]), int(parts[3])
px = parts[4]
for spec in sys.argv[2:]:
    box, _, label = spec.partition(":")
    x, y, bw, bh = map(int, box.split(","))
    acc = [0.0, 0.0, 0.0]
    n = 0
    for yy in range(y, y + bh):
        row = (yy * w + x) * 3
        for i in range(bw):
            for c in range(3):
                acc[c] += px[row + i * 3 + c] / mx
            n += 1
    rgb = [a / n for a in acc]
    L, a, b = lab(rgb)
    print(
        f"{label or box:>14}: RGB {tuple(round(v * 255) for v in rgb)}  L {L:5.1f} a {a:6.1f} b {b:6.1f}"
    )
