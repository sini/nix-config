"""Locate a ColorChecker's patch grid on a FastFoto page, for `scanin`.

The card's body is near black and the scanner's backing is light, so the card is the dark
region of the page; inside it, the patches are the bright blocks. Argyll's ColorChecker.cht
is drawn for X-Rite's card, and the Calibrite card's side text and ruler mislead scanin's
match unless the image is cropped to the patches themselves, which is what this finds.

Reads a binary PPM (downscaled; pass the scale) and prints an ImageMagick crop geometry in
full-resolution pixels, with a margin, plus a score: the mean chroma inside the grid, which
is high on the patch side of the card and near zero on its plain back.

usage: grid.py page.ppm SCALE
"""

import sys
from pathlib import Path

raw = Path(sys.argv[1]).read_bytes()
scale = float(sys.argv[2])
parts = raw.split(maxsplit=4)
w, h, mx = int(parts[1]), int(parts[2]), int(parts[3])
px = parts[4]


def at(x, y):
    i = (y * w + x) * 3
    return px[i] / mx, px[i + 1] / mx, px[i + 2] / mx


def extent(profile, frac):
    """First and last index whose value reaches frac of the profile's maximum."""
    top = max(profile)
    idx = [i for i, v in enumerate(profile) if v >= frac * top]
    return idx[0], idx[-1]


# 1. The card: dark pixels (every channel below 0.25; the backing reads about 0.6).
dark = [[max(at(x, y)) < 0.25 for x in range(w)] for y in range(h)]
x0, x1 = extent([sum(dark[y][x] for y in range(h)) for x in range(w)], 0.3)
y0, y1 = extent([sum(dark[y][x] for x in range(w)) for y in range(h)], 0.3)

# 2. The patches: solid, roughly square blocks of bright pixels inside the card. Text,
# ruler ticks and the ruler's baseline are thin or long, so they fail the squareness and
# fill tests. The black patch (D06) is too dark to count, but every row and column of the
# grid still has other patches, so the blocks' bounding box is the whole grid.
inside = {
    (x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if max(at(x, y)) > 0.2
}
blocks = []
seen = set()
for start in inside:
    if start in seen:
        continue
    seen.add(start)
    stack, comp = [start], []
    while stack:
        cx, cy = stack.pop()
        comp.append((cx, cy))
        for nb in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if nb in inside and nb not in seen:
                seen.add(nb)
                stack.append(nb)
    xs = [c[0] for c in comp]
    ys = [c[1] for c in comp]
    bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
    if 0.6 < bw / bh < 1.6 and len(comp) > 0.8 * bw * bh:
        blocks.append((min(xs), min(ys), max(xs), max(ys), len(comp)))
# Keep blocks near the largest's size: a patch, not a stray speck.
big = max(b[4] for b in blocks)
blocks = [b for b in blocks if b[4] > 0.4 * big]
gx0 = min(b[0] for b in blocks)
gy0 = min(b[1] for b in blocks)
gx1 = max(b[2] for b in blocks)
gy1 = max(b[3] for b in blocks)
print(f"{len(blocks)} patch blocks", file=sys.stderr)

# 3. Score: mean chroma (max - min channel) inside the grid.
n = s = 0
for y in range(gy0, gy1 + 1, 2):
    for x in range(gx0, gx1 + 1, 2):
        c = at(x, y)
        s += max(c) - min(c)
        n += 1

margin = 0.03 * max(gx1 - gx0, gy1 - gy0)
X0 = max(0, int((gx0 - margin) * scale))
Y0 = max(0, int((gy0 - margin) * scale))
X1 = int((gx1 + margin) * scale)
Y1 = int((gy1 + margin) * scale)
print(f"{X1 - X0}x{Y1 - Y0}+{X0}+{Y0} {s / n:.4f}")
