#!/usr/bin/env python3
"""Self-test: scans shaped like the FF-680W's, each batch with its expected routes.

The scanner returns its whole 8.5in-wide feed area: the item at the top on a
grey-blue band that runs about 0.4in past it, then white fill. Back sides carry a
white sensor-edge stripe down the left. fixtures/ holds a real scan (Epson's
leaflet, both sides), downscaled to 75dpi.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

DPI = 50
BAND = (200, 210, 218)
FIXTURES = Path(__file__).parent / "fixtures"


def scan(item, back=False):
    """Place an item as the scanner returns it."""
    w = int(8.48 * DPI)
    band = item.height + int(0.4 * DPI)
    page = Image.new("RGB", (w, band + int(2 * DPI)), (255, 255, 255))
    page.paste(BAND, (0, 0, w, band))
    page.paste(item, ((w - item.width) // 2, 0))
    if back:
        # Real stripes are 5-13px at 300dpi; wider here than erosion removes.
        page.paste((254, 255, 252), (0, 0, px(0.15), band))
    return page


def px(inches):
    return int(inches * DPI)


def colourful(w, h):
    hues = Image.linear_gradient("L").resize((px(w), px(h)))
    sv = Image.new("L", hues.size, 200)
    return Image.merge("HSV", (hues, sv, sv)).convert("RGB")


def greyscale(w, h):
    """A black-and-white print: no colour, mostly mid-tones."""
    ramp = (
        Image.linear_gradient("L")
        .resize((px(w), px(h)))
        .point(lambda v: 50 + v * 140 // 255)
    )
    return ramp.convert("RGB")


def text(w, h, paper=(255, 255, 255), lines=True):
    page = Image.new("RGB", (px(w), px(h)), paper)
    if lines:
        draw = ImageDraw.Draw(page)
        for y in range(px(0.4), page.height - px(0.4), px(0.3)):
            draw.rectangle((px(0.4), y, page.width - px(0.4), y + 2), fill=(20, 20, 20))
    return page


# Print backs are white paper: the band is far from it, so band left in a box reads as ink.
CARD = (255, 255, 255)
PAGES = {
    "photo": scan(colourful(6, 4)),
    "photo-bw": scan(greyscale(5, 7)),
    "photo-8x10": scan(colourful(8, 10)),
    "letter": scan(text(8.5, 11)),
    "receipt": scan(text(3, 10)),
    "leaflet-small": scan(text(5, 6)),
    "back-blank": scan(text(6, 4, CARD, lines=False), back=True),
    "back-notes": scan(text(6, 4, CARD), back=True),
    "letter-back": scan(text(8.5, 11), back=True),
}

CASES = [
    # (flags, pages, expected routes)
    ([], ["photo"], ["photo"]),
    ([], ["photo-bw"], ["photo"]),
    ([], ["photo-8x10"], ["photo"]),
    ([], ["letter"], ["document"]),
    ([], ["receipt"], ["document"]),
    # Photo-sized but text: content decides, not size.
    ([], ["leaflet-small"], ["document"]),
    # Duplex sheets, front and back in either order.
    (["--duplex"], ["back-blank", "photo"], ["blank", "photo"]),
    (["--duplex"], ["photo", "back-notes"], ["photo", "back"]),
    (["--duplex"], ["letter", "letter-back"], ["document", "document"]),
    (["--duplex"], ["letter", "back-blank"], ["document", "blank"]),
    # A batch keeps each sheet's route.
    (
        ["--duplex"],
        ["back-blank", "photo", "letter", "back-blank"],
        ["blank", "photo", "document", "blank"],
    ),
]

REAL = [
    (
        ["--dpi", "75", "--duplex"],
        [FIXTURES / "leaflet-side1.png", FIXTURES / "leaflet-side2.png"],
        ["document", "document"],
    ),
]


def run(tool, flags, files):
    out = subprocess.run(
        [tool, *flags, *map(str, files)], capture_output=True, text=True, check=True
    ).stdout.split()
    return out[0::2]


def main():
    tool = sys.argv[1]
    failed = 0
    with tempfile.TemporaryDirectory() as tmp:
        for name, page in PAGES.items():
            page.save(Path(tmp) / f"{name}.png")
        cases = [
            (
                ["--dpi", str(DPI), *flags],
                [Path(tmp) / f"{n}.png" for n in names],
                expected,
            )
            for flags, names, expected in CASES
        ] + REAL
        for flags, files, expected in cases:
            got = run(tool, flags, files)
            ok = got == expected
            failed += not ok
            label = " ".join([*flags[2:], *(f.stem for f in files)])
            print(f"{'ok  ' if ok else 'FAIL'} {label}: {got}")
            if not ok:
                print(f"     expected {expected}")
        # --trim-in-place leaves the item alone: a 6x4in print at DPI.
        run(tool, ["--dpi", str(DPI), "--trim-in-place"], [Path(tmp) / "photo.png"])
        size = Image.open(Path(tmp) / "photo.png").size
        ok = abs(size[0] - px(6)) <= 2 and abs(size[1] - px(4)) <= 2
        failed += not ok
        print(
            f"{'ok  ' if ok else 'FAIL'} --trim-in-place photo: {size}, expected ~{(px(6), px(4))}"
        )
        # --photo-rotate turns the picture side only: a portrait print's top-left
        # corner, marked red, ends at the bottom-right after 180 degrees.
        marked = colourful(4, 6)
        marked.paste((255, 0, 0), (0, 0, px(0.5), px(0.5)))
        scan(marked).save(Path(tmp) / "marked.png")
        page = text(8.5, 11)
        page.paste((0, 0, 255), (0, 0, px(0.5), px(0.5)))
        scan(page).save(Path(tmp) / "marked-letter.png")
        files = [Path(tmp) / "marked.png", Path(tmp) / "marked-letter.png"]
        flags = ["--dpi", str(DPI), "--trim-in-place", "--photo-rotate", "180"]
        run(tool, flags, files)
        turned = Image.open(files[0]).convert("RGB")
        corner = turned.getpixel((turned.width - 5, turned.height - 5))
        letter = Image.open(files[1]).convert("RGB").getpixel((5, 5))
        ok = corner == (255, 0, 0) and letter == (0, 0, 255)
        failed += not ok
        print(
            f"{'ok  ' if ok else 'FAIL'} --photo-rotate 180: photo corner {corner}, letter corner {letter}"
        )
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
