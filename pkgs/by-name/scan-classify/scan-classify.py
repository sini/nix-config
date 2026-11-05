#!/usr/bin/env python3
"""Route the pages of one scanner batch to immich (photos) or paperless (documents).

The scanner returns its whole feed area: the item on a grey-blue feed background
(the "band", as long as the item plus a margin), then white fill to the end of the
scan length. Each page is cut to the band and trimmed to the item, then judged by
content first: colour and mid-tones mark a photo, white paper with dark ink a
document. Size only breaks ties. A batch is one button press, usually uniform, so
undecided sheets take the batch's decided kind.

With --duplex, pages pair into sheets, front and back in either order: a blank side
is the back. Prints one line per page, in input order: `<route> <file>`, where route is
  photo     a print's picture side          -> immich
  back      a print's written-on back       -> immich, beside its front
  document  a page of a document            -> paperless, all pages as one PDF
  review    undecidable                     -> paperless, tagged needs-review
  blank     a blank side                    -> dropped
"""

import argparse
import sys
from collections import Counter
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageStat


def parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("pages", nargs="+", type=Path)
    p.add_argument("--dpi", type=float, required=True)
    p.add_argument("--duplex", action="store_true", help="pages pair into sheets")
    p.add_argument(
        "--trim-in-place", action="store_true", help="overwrite each page with its item"
    )
    # The feed background as the scanner renders it, and how far a pixel may stray.
    p.add_argument("--background", default="200,210,218")
    p.add_argument("--background-fuzz", type=int, default=24)
    # Content: mean HSV saturation (0-255), mid-tone share (luminance 40-200) and
    # white share (>= 225) of the trimmed item.
    p.add_argument("--photo-min-saturation", type=float, default=40)
    p.add_argument("--photo-min-midtones", type=float, default=0.45)
    p.add_argument("--document-max-saturation", type=float, default=30)
    p.add_argument("--document-max-midtones", type=float, default=0.3)
    p.add_argument("--document-min-white", type=float, default=0.4)
    # Size, for ties (inches): photo prints vs letter/A4 pages.
    p.add_argument("--photo-max-short", type=float, default=5.5)
    p.add_argument("--photo-max-long", type=float, default=7.5)
    p.add_argument("--document-min-short", type=float, default=8.2)
    # A side is blank when under this share of it is ink.
    p.add_argument("--blank-max-ink", type=float, default=0.002)
    return p.parse_args(argv)


def is_background(px, bg, fuzz):
    return all(abs(a - b) <= fuzz for a, b in zip(px, bg, strict=True))


def trim(img, bg, fuzz):
    """Cut a page to the feed band, then to the item on it."""
    rgb = img.convert("RGB")
    w, h = rgb.size
    load = rgb.load()
    cols = range(0, w, max(1, w // 64))

    # Below the item the band fills the row; its last rows are ragged, part fill.
    def bg_row(y):
        return sum(is_background(load[x, y], bg, fuzz) for x in cols) * 2 >= len(cols)

    band = next((y for y in range(h - 1, -1, -1) if bg_row(y)), None)
    if band is None:  # no feed background: nothing to trim against
        return rgb
    # Back off the band's ragged last rows.
    band = max(1, band - 8)
    rgb = rgb.crop((0, 0, w, band))
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, bg)).convert("L")
    # Erode, so dust and thin scan-edge lines do not widen the box.
    mask = diff.point(lambda v: 255 if v > fuzz else 0).filter(ImageFilter.MinFilter(5))
    # The item ends above the band's end, so a column still set there is a back
    # side's sensor-edge stripe; left in, it would pull band into the box as ink.
    edge = mask.load()
    stripes = [x for x in range(w) if edge[x, band - 1]]
    if len(stripes) < w:
        for x in stripes:
            mask.paste(0, (x, 0, x + 1, band))
    box = mask.getbbox()
    if not box:
        return rgb
    # Grow back the 2px the erosion took from each edge.
    left, top, right, bottom = box
    return rgb.crop(
        (max(0, left - 2), max(0, top - 2), min(w, right + 2), min(band, bottom + 2))
    )


def share(gray, lo, hi):
    hist = gray.histogram()
    return sum(hist[lo:hi]) / max(1, sum(hist))


def is_blank(page, a):
    # Inset 2%: the item's edge shadow is not ink.
    dx, dy = page.width // 50, page.height // 50
    gray = page.crop((dx, dy, page.width - dx, page.height - dy)).convert("L")
    # Ink is anything far from the paper's tone, lighter or darker: a photo with no
    # paper border has no dominant tone at all.
    paper = max(range(256), key=gray.histogram().__getitem__)
    ink = share(gray, 0, max(0, paper - 40)) + share(gray, min(256, paper + 41), 256)
    return ink < a.blank_max_ink


def classify(page, a):
    gray = page.convert("L")
    saturation = ImageStat.Stat(page.convert("HSV").getchannel("S")).mean[0]
    midtones = share(gray, 40, 200)
    white = share(gray, 225, 256)
    if saturation >= a.photo_min_saturation or midtones >= a.photo_min_midtones:
        return "photo"
    if (
        saturation <= a.document_max_saturation
        and midtones <= a.document_max_midtones
        and white >= a.document_min_white
    ):
        return "document"
    short, long = sorted(d / a.dpi for d in page.size)
    if short <= a.photo_max_short and long <= a.photo_max_long:
        return "photo"
    if short >= a.document_min_short:
        return "document"
    return None


def sheet_routes(sides, a):
    """Routes for one sheet's sides, and the sheet's kind (None when undecided)."""
    blank = [is_blank(s, a) for s in sides]
    kinds = [None if b else classify(s, a) for s, b in zip(sides, blank, strict=True)]
    kind = "photo" if "photo" in kinds else "document" if "document" in kinds else None
    if all(blank):
        return ["blank"] * len(sides), None
    routes = []
    pictured = False
    for b, k in zip(blank, kinds, strict=True):
        if b:
            routes.append("blank")
        elif kind == "photo":
            # The first picture side is the front; any other written side its back.
            routes.append("back" if pictured or k != "photo" else "photo")
            pictured = pictured or k == "photo"
        else:
            routes.append(kind)
    return routes, kind


def route(paths, a):
    bg = tuple(int(v) for v in a.background.split(","))
    pages = [trim(Image.open(p), bg, a.background_fuzz) for p in paths]
    if a.trim_in_place:
        for page, path in zip(pages, paths, strict=True):
            page.save(path, dpi=(a.dpi, a.dpi))
    step = 2 if a.duplex else 1
    sheets = [sheet_routes(pages[i : i + step], a) for i in range(0, len(pages), step)]
    decided = Counter(k for _, k in sheets if k)
    if len(decided) > 1:
        print(f"scan-classify: mixed batch {dict(decided)}", file=sys.stderr)
    fill = next(iter(decided)) if len(decided) == 1 else "review"
    return [r if r is not None else fill for routes, _ in sheets for r in routes]


def main(argv=None):
    a = parse_args(sys.argv[1:] if argv is None else argv)
    for r, p in zip(route(a.pages, a), a.pages, strict=True):
        print(r, p)


if __name__ == "__main__":
    main()
