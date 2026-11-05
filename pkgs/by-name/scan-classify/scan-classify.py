#!/usr/bin/env python3
"""Route the pages of one scanner batch to immich (photos) or paperless (documents).

Each front is trimmed to its paper (the feed background is dark) and measured in
inches at --dpi. Photo prints, letter/A4 pages and receipts are told apart by
size; anything between falls back to colourfulness. A batch is one button press,
usually uniform, so undecided pages take the batch's decided kind.

Prints one line per page, in input order: `<route> <file>`, where route is
  photo     front of a print            -> immich
  back      non-blank back of a print   -> immich, beside its front
  document  page of a document          -> paperless, all pages as one PDF
  review    undecidable                 -> paperless, tagged needs-review
  blank     blank back                  -> dropped
"""

import argparse
import sys
from collections import Counter
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


def parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("pages", nargs="+", type=Path)
    p.add_argument("--dpi", type=float, required=True)
    p.add_argument("--duplex", action="store_true", help="pages alternate front, back")
    p.add_argument("--photo-max-short", type=float, default=5.5)
    p.add_argument("--photo-max-long", type=float, default=7.5)
    p.add_argument("--document-min-short", type=float, default=8.2)
    p.add_argument("--receipt-max-short", type=float, default=3.3)
    p.add_argument("--receipt-min-long", type=float, default=6.0)
    # Colourfulness, for sizes no rule claims: mean HSV saturation (0-255) and
    # the share of near-white pixels.
    p.add_argument("--photo-min-saturation", type=float, default=60)
    p.add_argument("--document-max-saturation", type=float, default=30)
    p.add_argument("--document-min-white", type=float, default=0.6)
    # A back is blank when under this share of its pixels is ink.
    p.add_argument("--blank-max-ink", type=float, default=0.002)
    return p.parse_args(argv)


def trim(img, fuzz=40):
    """Crop to the paper: everything differing from the corner background."""
    rgb = img.convert("RGB")
    w, h = rgb.size
    corners = [
        rgb.getpixel(xy) for xy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))
    ]
    bg = tuple(sorted(c[i] for c in corners)[1] for i in range(3))
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, bg)).convert("L")
    bbox = diff.point(lambda v: 255 if v > fuzz else 0).getbbox()
    return rgb.crop(bbox) if bbox else rgb


def share(gray, keep):
    """Fraction of pixels of an L image for which keep(value) holds."""
    hist = gray.histogram()
    return sum(n for v, n in enumerate(hist) if keep(v)) / max(1, sum(hist))


def classify_front(page, a):
    short, long = sorted(d / a.dpi for d in page.size)
    if short <= a.photo_max_short and long <= a.photo_max_long:
        return "photo"
    if short >= a.document_min_short:
        return "document"
    if short <= a.receipt_max_short and long > a.receipt_min_long:
        return "document"
    saturation = ImageStat.Stat(page.convert("HSV").getchannel("S")).mean[0]
    white = share(page.convert("L"), lambda v: v >= 225)
    if saturation >= a.photo_min_saturation and white < a.document_min_white:
        return "photo"
    if saturation <= a.document_max_saturation and white >= a.document_min_white:
        return "document"
    return None


def is_blank(page, a):
    gray = page.convert("L")
    paper = max(range(256), key=gray.histogram().__getitem__)
    return share(gray, lambda v: v < paper - 60) < a.blank_max_ink


def route(paths, a):
    pages = [trim(Image.open(p)) for p in paths]
    fronts = pages[::2] if a.duplex else pages
    kinds = [classify_front(f, a) for f in fronts]
    decided = Counter(k for k in kinds if k)
    if len(decided) == 1:
        kinds = [k or next(iter(decided)) for k in kinds]
    elif len(decided) > 1:
        print(f"scan-classify: mixed batch {dict(decided)}", file=sys.stderr)
    kinds = [k or "review" for k in kinds]

    routes = []
    for i, kind in enumerate(kinds):
        routes.append(kind)
        if a.duplex and 2 * i + 1 < len(pages):
            back = pages[2 * i + 1]
            if is_blank(back, a):
                routes.append("blank")
            else:
                # A document's back is its next page; a photo's back travels with it.
                routes.append("back" if kind == "photo" else kind)
    return routes


def main(argv=None):
    a = parse_args(sys.argv[1:] if argv is None else argv)
    for r, p in zip(route(a.pages, a), a.pages, strict=True):
        print(r, p)


if __name__ == "__main__":
    main()
