"""Reference values for a printtarg chart printed by a photo lab from the sRGB file: each
patch's RGB (from the .ti2) read as sRGB, as D50 XYZ, keyed by the patch location the .cht
uses, so `scanin` can read it like ColorChecker.cie.

usage: labref.py chart.ti2 out.cie
"""

import sys
from pathlib import Path

# sRGB primaries adapted to D50 (the ICC PCS), XYZ 0-100.
M = [
    [0.4360747, 0.3850649, 0.1430804],
    [0.2225045, 0.7168786, 0.0606169],
    [0.0139322, 0.0971045, 0.7141733],
]


def decode(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


lines = Path(sys.argv[1]).read_text().split("\n")
fields = next(line for line in lines if line.startswith("SAMPLE_ID")).split()
start, end = lines.index("BEGIN_DATA") + 1, lines.index("END_DATA")
loc = fields.index("SAMPLE_LOC")
rgb = [fields.index(k) for k in ("RGB_R", "RGB_G", "RGB_B")]

rows = []
for line in lines[start:end]:
    if not line.strip():
        continue
    v = line.split()
    lin = [decode(float(v[i]) / 100) for i in rgb]
    xyz = [100 * sum(M[r][c] * lin[c] for c in range(3)) for r in range(3)]
    rows.append(f"{v[loc].strip(chr(34))} {xyz[0]:.4f} {xyz[1]:.4f} {xyz[2]:.4f}")

Path(sys.argv[2]).write_text(
    "CTI3\n\n"
    'DESCRIPTOR "Lab-printed chart reference: patch RGB read as sRGB (D50)"\n'
    'ORIGINATOR "labref.py"\n\n'
    "NUMBER_OF_FIELDS 4\nBEGIN_DATA_FORMAT\nSAMPLE_ID XYZ_X XYZ_Y XYZ_Z\nEND_DATA_FORMAT\n\n"
    f"NUMBER_OF_SETS {len(rows)}\nBEGIN_DATA\n" + "\n".join(rows) + "\nEND_DATA\n"
)
print(f"{len(rows)} patches")
