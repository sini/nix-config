"""Extract the tone curves sane-backends' epsonds driver uploads for one `lut_id`, as CSV and
as an SVG chart against the identity curve.

usage: lut-extract.py backend/epsonds.c LUT_ID out.csv out.svg
"""

import re
import sys
from pathlib import Path

src, lut_id, csv_out, svg_out = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
text = Path(src).read_text()

curves = {}
for name in ("LUT_R", "LUT_G", "LUT_B"):
    m = re.search(
        rf"static unsigned char {name}\[\]\[256\]\s*=\s*\{{(.*?)\n\}};", text, re.DOTALL
    )
    tables = re.findall(r"\{([^{}]*)\}", m.group(1))
    values = [int(v, 16) for v in re.findall(r"0x([0-9a-fA-F]+)", tables[lut_id])]
    assert len(values) == 256, (name, len(values))
    curves[name[-1]] = values

with open(csv_out, "w") as f:
    f.write("input,R,G,B\n")
    f.writelines(
        f"{i},{curves['R'][i]},{curves['G'][i]},{curves['B'][i]}\n" for i in range(256)
    )

# A 480x480 plot area with a 40px margin; y grows downward in SVG.
size, pad = 480, 40


def pt(x, y):
    return f"{pad + x * size / 255:.1f},{pad + size - y * size / 255:.1f}"


lines = [
    (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size + 2 * pad}" height="{size + 2 * pad}" '
        'font-family="sans-serif" font-size="12">'
    ),
    f'<rect x="{pad}" y="{pad}" width="{size}" height="{size}" fill="#fff" stroke="#888"/>',
    f'<polyline fill="none" stroke="#999" stroke-dasharray="4 3" points="{pt(0, 0)} {pt(255, 255)}"/>',
]
for c, colour in (("R", "#d33"), ("G", "#3a3"), ("B", "#36c")):
    points = " ".join(pt(i, v) for i, v in enumerate(curves[c]))
    lines.append(
        f'<polyline fill="none" stroke="{colour}" stroke-width="1.5" points="{points}"/>'
    )
lines += [
    f'<text x="{pad}" y="{pad - 12}">epsonds tone curves, lut_id {lut_id} (dashed: identity, lut_id 0)</text>',
    f'<text x="{pad + size / 2 - 60}" y="{pad + size + 28}">scanner value in (0-255)</text>',
    f'<text x="12" y="{pad + size / 2}" transform="rotate(-90 12 {pad + size / 2})">value out</text>',
    "</svg>",
]
Path(svg_out).write_text("\n".join(lines) + "\n")
print(
    f"lut_id {lut_id}: inputs <= {max(i for i in range(256) if curves['G'][i] == 0)} -> 0, "
    f"inputs >= {min(i for i in range(256) if curves['G'][i] == 255)} -> 255"
)
