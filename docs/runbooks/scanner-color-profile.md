# Runbook: colour-profile the FF-680W scanner

Scans from the Epson FastFoto FF-680W (`services.scanning.epson` on
**bitstream**, `modules/den/aspects/services/scanning/epson.nix`) look darker,
higher-contrast and more saturated than the original prints.

## Status (2026-11-06)

- **Root cause found: the SANE driver, not the scanner.** `epsonds` files the
  FF-680W under the DS-530 document scanners (`lut_id` 2, `backend/epsonds.c`
  model table). Every colour scan therefore uploads that family's tone curves,
  which crush device inputs 0–39 to black and clip 210 and up to white, plus the
  DS-530 colour matrix. The scans are clipped at both ends before any profile
  sees them, and no profile can recover that.
- **The fix, built but not deployed:**
  `modules/den/aspects/services/scanning/_sane-ff680w-native-tone.patch` changes
  the FF-680W to `lut_id` 0. That uploads the identity curves and skips the
  matrix, so the scanner returns its own response at gamma 1.8 (the driver's
  `#GMMUG18`), unclipped. Built and tested from cortex: the card's black patch
  reads 12.6/100 instead of 0, its white 92 instead of 100.
- **Profile: built, not committed.**
  `~/Documents/scanner-profile/native/ff680w.icc` on cortex: a shaper/matrix
  profile from all 24 card patches of a native-tone scan, with neutral end
  anchors (below). On the card it fits at ΔE2000 average 2.35, max 5.8 (B06
  orange-yellow).
- **Owner ruling: the card is the reference.** Trust the measured card over
  judging single prints by eye or phone photo. See "Metamerism" for the known
  limit of that choice.

### Remaining work, in order

1. **More card scans.** Scan the card 2–3 more times through the patched driver,
   average the `.ti3` measurements, and rebuild the profile. This reduces
   per-scan noise and measures repeatability, which the drift check (Later)
   needs.
2. **Cropping.** With identity curves the scanner returns a full-length page
   (5096 × 9283 at 600 dpi) with a lighter background, and `scan-classify`
   currently routes the reference photo's front as `document`. Retune its trim
   and classification against the native scans in
   `/tmp/claude-1000/…/scratchpad/profile/native/` (copy them out first:
   `page-00{1,2}.png` are the card, `photo-00{1,2}.png` the reference print).
3. **Wire the patch.** Give epson-scan a `sane-backends` with the patch
   (`overrideAttrs` adding it to `patches`; `doCheck = false` was used for the
   test build). Only that service needs it.
4. **Embed the profile.** Commit it as
   `modules/den/aspects/services/scanning/ff-680w.icc`. Add an `iccProfile`
   setting to `services.scanning.epson`, and have the batch script _assign_ it
   to each cropped photo page before upload. Assign, not convert: verify that
   pixel values are unchanged and that `magick identify -verbose page.png` lists
   the profile.
5. **The held spool.** The photo batches kept in
   `/var/lib/private/epson-scan/spool/` were scanned with the stock driver; this
   profile does not apply to them. Rescan those prints after the deploy, then
   delete the old batches.
6. **Deploy bitstream** (owner approval), then add the immich API key.

Until step 6, keep the immich key unset: epson-scan holds every photo batch in
its spool, and immich cannot have a profile assigned after upload.

## Scanning from cortex, without the button

The scanner (10.9.10.1, TCP 1865) is reachable from cortex. Load the item and do
**not** press the scan button: the button makes bitstream's epson-scan take the
batch. With the patched `sane-backends` built (`nix build --impure --expr` over
`sane-backends.overrideAttrs`, adding the patch):

```bash
c=$(mktemp -d)
printf 'net 10.9.10.1\n' > "$c/epsonds.conf"; printf 'epsonds\n' > "$c/dll.conf"
SANE_CONFIG_DIR=$c "$SANE/bin/scanimage" -d epsonds:net:10.9.10.1 \
  --source "ADF Duplex" --mode Color --resolution 600 --adf-skew=yes \
  --format png --batch="page-%03d.png"
```

These are epson-scan's own settings. `SANE_DEBUG_EPSONDS=1 scanimage -A` prints
`scanner lut_id`: 0 means the patched driver is in use.

## Building the profile

Tools: Argyll CMS (`nix shell nixpkgs#argyllcms`), with
`A=$(nix build --no-link --print-out-paths nixpkgs#argyllcms)/share/argyllcms`.

1. **Crop to the patch grid, not the card.** Argyll's `ColorChecker.cht` is
   drawn for X-Rite's card. The Calibrite card's side text and millimetre ruler
   mislead `scanin`'s matching (it picked a rotation one column off). Crop to
   the 24 patches with a small margin, then `magick … -depth 8 target.tif` (an
   untagged PNG is not colour-converted).
2. **Read the patches:**
   `scanin -v -p -dipn target.tif "$A/ColorChecker.cht" "$A/ColorChecker.cie"`.
   A good match has one rotation scoring far below the other (239 against 3306
   on the native scan). **Open `diag.tif`**: every sample box must sit inside
   its patch.
3. **Anchor the ends.** The card spans only L\*20.5 (D06) to L\*96.5 (D01), and
   prints go beyond both, so a profile fitted to the card alone extrapolates
   there: it gave device black b\* −14 and device white a\* −3.5, b\* +3.7.
   Append two neutral samples to the `.ti3` before fitting: `K00` (device 0,0,0
   → XYZ 0,0,0) and `W00` (device 100,100,100 → D50 white 96.422, 100, 82.521),
   and bump `NUMBER_OF_SETS`. The script is
   `~/Documents/scanner-profile/native/anchor.py`.
4. **Fit a shaper/matrix:**
   `colprof -qh -as -A Epson -M "FastFoto FF-680W" -D "…" -C "…" anchored`. A
   LUT profile would overfit 24 patches.
5. **Check:** `profcheck -k target.ti3 anchored.icc` (the 24 real patches only;
   expect an average around 2–2.5), and
   `printf '0 0 0\n1 1 1\n' | xicclu -ff -ir -pl anchored.icc` (both should be
   neutral).

## What was tried, and why it was rejected

All on the stock driver's clipped scans, before the driver cause was found:

| Approach                                             | Result                                                                           |
| ---------------------------------------------------- | -------------------------------------------------------------------------------- |
| Card profile, as is                                  | Correct to the card, but device 0 read as L\*24: every shadow lifted, washed out |
| Black-point-compensated card data                    | Blacks fixed, wall greener, still darker than the print                          |
| Tone-preserving (scanner lightness, card hue/chroma) | Better, still too dark and saturated                                             |

On the native scan, a plain gamma 1.8 → sRGB conversion with no card at all
landed within 1–2 L\* of the print; the card's grey patches add 2–5 L\* of
midtone accuracy on top. That is why the clean data comes first: no profile
could fix the clipped data.

## Metamerism: the known limit

The scanner's LEDs and sensor do not see colour the way the eye does, so
different materials can disagree. The card's patches are pigments; photo prints
are dyes. On the reference print (the 2006 "Pirate's Dinner Adventure" photo) a
grey-brown stone wall reads green to the scanner (a\* −8 to −10 on the native
scan), and the full card profile pushes it slightly further. The owner's ruling
(above) is to trust the card regardless. If dye prints prove systematically off
across many photos, the cheap fix is a dye-based target: a ~300-patch chart
image printed at a photo lab (Costco, auto-correction off), profiled against the
file's own values. An IT8.7/2 target on photo paper does the same job properly
but costs far more.

## Files

On cortex, under `~/Documents/scanner-profile/`:

- `native/ff680w.icc`: the candidate profile;
- `native/anchored.ti3`: its measurements;
- `native/anchor.py`: the end-anchor script;
- `native/target.ti3`, `diag.tif`: the native card measurement;
- `native/*-compare.jpg`: the side-by-side comparisons;
- the top level: the stock-driver attempts, kept for reference.

## Later

- **Drift check.** Rescan the card now and then (and after any Epson firmware
  update), run `profcheck` against the committed profile, and rebuild if the
  average rises.
- **Upstream.** The FF-680W's `lut_id` in sane-backends is worth reporting
  upstream: a photo scanner should not get document tone curves.
- A profile is valid only for the settings it was made at: 600 dpi, colour,
  native tone. Any change means a new card scan.
