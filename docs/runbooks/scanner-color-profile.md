# Runbook: colour-profile the FF-680W scanner

Scans from the Epson FastFoto FF-680W (`services.scanning.epson` on
**bitstream**, `modules/den/aspects/services/scanning/epson.nix`) look
oversaturated next to the original prints. `scanimage` writes the scanner's
native RGB with no colour profile, so every viewer reads it as sRGB, and the
scanner's native space is not sRGB. Epson's own app corrects this inside its
closed libraries; neither Epson's site nor its Linux driver (`epsonscan2`, whose
`share/epsonscan2` holds only firmware blobs) ships an ICC profile for this
model. The shift is systematic, the same on every scan, so one profile made from
this unit fixes all of them.

The fix: scan a colour target with the scanner, build an ICC profile from it
with Argyll CMS, and **embed** (assign) that profile in every scan. Embedding
tags the pixels without changing them, so scans keep the scanner's raw data, and
anything colour-managed (immich's thumbnails, browsers, image viewers) shows the
corrected colour.

## Before the profile exists: hold photo uploads

A photo uploaded to immich untagged stays untagged there; immich cannot have a
profile assigned afterwards, so it would need re-uploading. Until the profile is
in place:

- set up the **paperless** token only (documents are not colour-critical);
- leave the **immich** API key unset. epson-scan then keeps every photo batch in
  its spool, cropped and raw, at `/var/lib/private/epson-scan/spool/<stamp>/` on
  bitstream, where the profile can be assigned before upload.

## 1. Get a target

The target must go through the FastFoto's sheet feeder, so it has to be thin and
flexible like a print. Two choices:

| Target                                                              | Patches | Where                                                              | Notes                                                                                                                                                                                                            |
| ------------------------------------------------------------------- | ------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Calibrite ColorChecker Classic **Mini** (CCC-MINI), ~2.25 × 3.25 in | 24      | Amazon                                                             | Argyll ships its layout and reference values. A coarse profile: fixes saturation and white balance, not fine hue errors. Feed the bare card only, never its sleeve; if it is too stiff to feed, do not force it. |
| IT8.7/2 **reflective** target on photo paper, 4×6 or 5×7            | ~260    | Wolf Faust (coloraid.de) or LaserSoft (silverfast.com), not Amazon | Feeds like any print; a much finer profile. Comes with a reference data file for its batch, which is required.                                                                                                   |

Not usable: the full-size ColorChecker Classic (8 × 11.5 in rigid board), the
ColorChecker Passport (plastic case), and any "transparency", "slide" or "film"
target.

## 2. Scan the target

Scan it exactly as epson-scan scans photos, so the profile matches the data it
will tag: 600 dpi, colour, skew correction, nothing else. On bitstream:

```bash
mkdir -p ~/scanner-profile && cd ~/scanner-profile
c=$(mktemp -d)
printf 'net 10.9.10.1\n' > "$c/epsonds.conf"; printf 'epsonds\n' > "$c/dll.conf"
SANE_CONFIG_DIR=$c nix shell nixpkgs#sane-backends -c \
  scanimage -d epsonds:net:10.9.10.1 --source "ADF Front" --mode Color \
  --resolution 600 --adf-skew=yes --format png -o target-raw.png
```

Load the target, then run the command; it scans what is in the feeder without
the button. Then crop it to the card with the same code epson-scan uses, and
convert to TIFF, which `scanin` reads. ImageMagick must not convert colour here,
and on an untagged PNG it does not:

```bash
nix run ~/nix-config#scan-classify -- --dpi 600 --trim-in-place target-raw.png
nix shell nixpkgs#imagemagick -c magick target-raw.png -depth 8 target.tif
```

(`~/nix-config` is wherever the repo is checked out.)

## 3. Read the patches

ColorChecker Mini:

```bash
A=$(nix build --no-link --print-out-paths nixpkgs#argyllcms)/share/argyllcms
nix shell nixpkgs#argyllcms -c \
  scanin -v -p -dipn target.tif "$A/ColorChecker.cht" "$A/ColorChecker.cie"
```

IT8.7/2: use `"$A/it8.cht"` and the target's own reference file (for example
`R231215.txt`) in place of `ColorChecker.cie`.

`scanin` writes `target.ti3` (the measured patches) and `diag.tif`. **Open
`diag.tif`**: every patch must have its sample box inside it. If the boxes are
off, rescan with the card squarer in the feeder, or drop `-p`.

## 4. Build the profile

```bash
nix shell nixpkgs#argyllcms -c \
  colprof -v -qm -as -A "Epson" -M "FastFoto FF-680W" \
  -D "FF-680W 600dpi (ColorChecker Mini)" target
```

`-as` (shaper + matrix) suits 24 patches; a LUT profile would overfit them. With
an IT8 target, use `-qh -al` (high-quality Lab LUT) instead, and name the
description after the target.

Check the fit:

```bash
nix shell nixpkgs#argyllcms -c profcheck -k target.ti3 target.icc
```

An average ΔE around 1–3 is good for a 24-patch shaper/matrix. Large errors
usually mean bad patch boxes in step 3.

## 5. Compare against a print

Take one photo's spooled scan, convert it to sRGB through the new profile, and
compare it on screen with the original print:

```bash
nix shell nixpkgs#imagemagick -c magick photo.png -depth 8 photo.tif
nix shell nixpkgs#argyllcms -c \
  cctiff -ip target.icc -ip "$A/sRGB.icm" photo.tif photo-srgb.tif
xdg-open photo.png; xdg-open photo-srgb.tif
```

If it is still visibly off, especially in hue, the 24-patch profile has reached
its limit: get the IT8 target and repeat from step 2.

## 6. Put it in place

1. Commit the profile next to the aspect, as
   `modules/den/aspects/services/scanning/ff-680w.icc`.
2. Add an `iccProfile` setting to `services.scanning.epson` (**not built yet**):
   the batch script assigns the profile to each cropped page before upload. For
   PNG pages that is an assign, not a conversion: verify after the change that
   pixel values are unchanged and that `magick identify -verbose page.png` lists
   the profile.
3. Assign the profile to every batch already in the spool the same way, then add
   the immich API key and deploy bitstream; the kept batches upload on the next
   retry.

## Later

- Moving to an IT8 target means a new profile; the old one stays in git history.
- If the scan settings change (resolution, or Epson firmware), rescan the
  target: a profile is only valid for the settings it was made at.
