"""Add neutral end anchors to a card .ti3: device black (0,0,0) as true black and device
white (1,1,1) as the D50 white, so the profile stays neutral where it must extrapolate past
the card's own black (L*20) and white (L*96) patches. usage: anchor.py in.ti3 out.ti3"""

import sys
from pathlib import Path

src, dst = sys.argv[1], sys.argv[2]
lines = Path(src).read_text().split("\n")
fields = next(l for l in lines if l.startswith("SAMPLE_ID")).split()
end = lines.index("END_DATA")


def row(name, xyz, rgb):
    v = {
        "SAMPLE_ID": name,
        "XYZ_X": xyz[0],
        "XYZ_Y": xyz[1],
        "XYZ_Z": xyz[2],
        "RGB_R": rgb,
        "RGB_G": rgb,
        "RGB_B": rgb,
    }
    return " ".join(str(v.get(f, 0)) for f in fields) + " "


lines[end:end] = [row("K00", (0, 0, 0), 0), row("W00", (96.422, 100.0, 82.521), 100)]
out = "\n".join(lines)
n = next(l for l in lines if l.startswith("NUMBER_OF_SETS"))
out = out.replace(n, f"NUMBER_OF_SETS {int(n.split()[1]) + 2}")
Path(dst).write_text(out)
