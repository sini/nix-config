#!/usr/bin/env python3
"""Self-test: synthetic scans on a dark feed background, each with its expected route."""

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

DPI = 100
FEED = (40, 40, 40)


def scan(paper):
    """Place paper on the feed background, as the scanner returns it."""
    canvas = Image.new("RGB", (paper.width + 60, paper.height + 60), FEED)
    canvas.paste(paper, (30, 30))
    return canvas


def colourful(w, h):
    hues = Image.linear_gradient("L").resize((int(w * DPI), int(h * DPI)))
    sv = Image.new("L", hues.size, 200)
    return Image.merge("HSV", (hues, sv, sv)).convert("RGB")


def text_page(w, h, colour=(255, 255, 255)):
    page = Image.new("RGB", (int(w * DPI), int(h * DPI)), colour)
    draw = ImageDraw.Draw(page)
    for y in range(40, page.height - 40, 30):
        draw.rectangle((40, y, page.width - 40, y + 8), fill=(20, 20, 20))
    return page


def flat(w, h, colour):
    return Image.new("RGB", (int(w * DPI), int(h * DPI)), colour)


CREAM = (245, 240, 225)
PAGES = {
    "photo4x6": colourful(4, 6),
    "photo8x10": colourful(8, 10),
    "letter": text_page(8.5, 11),
    "receipt": text_page(3, 10),
    "memo8x10": text_page(8, 10),
    "grey8x10": flat(8, 10, (128, 128, 128)),
    "back-blank": flat(4, 6, CREAM),
    "back-notes": text_page(4, 6, CREAM),
}

CASES = [
    # (flags, pages, expected routes)
    ([], ["photo4x6"], ["photo"]),
    ([], ["letter"], ["document"]),
    ([], ["receipt"], ["document"]),
    ([], ["photo8x10"], ["photo"]),
    ([], ["memo8x10"], ["document"]),
    ([], ["grey8x10"], ["review"]),
    # An undecided page takes the batch's kind.
    ([], ["letter", "grey8x10"], ["document", "document"]),
    (
        ["--duplex"],
        ["photo4x6", "back-blank", "photo4x6", "back-notes"],
        ["photo", "blank", "photo", "back"],
    ),
    (["--duplex"], ["letter", "letter"], ["document", "document"]),
    # A mixed batch keeps per-page routes.
    ([], ["photo4x6", "letter"], ["photo", "document"]),
]


def main():
    tool = sys.argv[1]
    failed = 0
    with tempfile.TemporaryDirectory() as tmp:
        for name, paper in PAGES.items():
            scan(paper).save(Path(tmp) / f"{name}.png", dpi=(DPI, DPI))
        for flags, names, expected in CASES:
            files = [str(Path(tmp) / f"{n}.png") for n in names]
            out = subprocess.run(
                [tool, "--dpi", str(DPI), *flags, *files],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.split()
            got = out[0::2]
            ok = got == expected
            failed += not ok
            print(f"{'ok  ' if ok else 'FAIL'} {' '.join(flags + names)}: {got}")
            if not ok:
                print(f"     expected {expected}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
