"""Synthesize a .ti3 whose device->XYZ relation is exactly "apply the card's grey curves, then
read the result as sRGB". colprof's shaper/matrix model fits that exactly (per-channel curves
followed by the sRGB matrix), so the resulting ICC profile embeds the grey calibration and
leaves the scanner's colour as it is.

usage: synth.py grey-clut.ppm out.ti3
"""

import sys
from pathlib import Path

clut_path, out = sys.argv[1], sys.argv[2]
raw = Path(clut_path).read_bytes()
header = raw.split(maxsplit=4)
data = header[4]
curves = [[data[i * 3 + c] / 255 for i in range(256)] for c in range(3)]

M = [
    [0.4360747, 0.3850649, 0.1430804],
    [0.2225045, 0.7168786, 0.0606169],
    [0.0139322, 0.0971045, 0.7141733],
]


def curve(c, x):  # linear interpolation in the 256-entry curve
    p = x * 255
    i = min(int(p), 254)
    t = p - i
    return curves[c][i] * (1 - t) + curves[c][i + 1] * t


def decode(s):
    return s / 12.92 if s <= 0.04045 else ((s + 0.055) / 1.055) ** 2.4


rows = []
steps = [i / 16 for i in range(17)]
n = 0
for r in steps:
    for g in steps:
        for b in steps:
            dev = (r, g, b)
            lin = [decode(curve(c, dev[c])) for c in range(3)]
            xyz = [100 * sum(M[k][j] * lin[j] for j in range(3)) for k in range(3)]
            n += 1
            rows.append(
                f"{n} {xyz[0]:.5f} {xyz[1]:.5f} {xyz[2]:.5f} {r * 100:.5f} {g * 100:.5f} {b * 100:.5f}"
            )

with open(out, "w") as f:
    f.write(
        'CTI3\n\nDESCRIPTOR "Argyll Calibration Target chart information 3"\nORIGINATOR "synth.py"\n'
        'DEVICE_CLASS "INPUT"\nCOLOR_REP "XYZ_RGB"\n\nNUMBER_OF_FIELDS 7\nBEGIN_DATA_FORMAT\n'
        "SAMPLE_ID XYZ_X XYZ_Y XYZ_Z RGB_R RGB_G RGB_B\nEND_DATA_FORMAT\n\n"
        f"NUMBER_OF_SETS {len(rows)}\nBEGIN_DATA\n" + "\n".join(rows) + "\nEND_DATA\n"
    )
print(f"{len(rows)} samples")
