# Runbook: colour-profile the FF-680W scanner

Scans from the Epson FastFoto FF-680W (`services.scanning.epson` on
**bitstream**, `modules/den/aspects/services/scanning/epson.nix`) look darker,
higher-contrast and more saturated than the original prints. The findings, data
and tools behind this runbook are in
[`docs/scanner-color/`](../scanner-color/README.md).

## Status (2026-11-07)

- **Root cause: the SANE driver, not the scanner.** `epsonds` files the FF-680W
  under the DS-530 document scanners (`lut_id` 2, `backend/epsonds.c` model
  table). Every colour scan therefore uploads that family's tone curves, which
  crush device inputs 0–38 to black and clip 210 and up to white, plus the
  DS-530 colour matrix.
- **Fixed in epson-scan** (`services.scanning.epson`, `nativeTone`, on by
  default). It scans through sane-backends patched with
  `_sane-ff680w-native-tone.patch`, which moves the FF-680W to `lut_id` 0:
  identity curves and no matrix, so the scanner's own response at gamma 1.8,
  unclipped.
  - `scan-classify --classify-lut` judges each page through the stock curve
    (`pkgs/by-name/scan-classify/epsonds-lut2.csv`), so the feed band colour and
    every routing threshold still hold.
  - The saved pages keep the native pixels.
- **Profile embedded** (`iccProfile`, default
  `modules/den/aspects/services/scanning/ff-680w.icc`).
  - `scan-classify --icc-profile` assigns it to each photo and back page. The
    pixels are unchanged; documents for paperless stay untagged.
  - It's a shaper/matrix profile from the mean of three native card scans, with
    neutral end anchors. On the card it fits at ΔE2000 average 2.36, max 5.8
    (B06 orange-yellow).
  - Repeatability: the three scans differ by 0.27/100 per patch on average,
    worst 0.53 (D01).
- **Checked:** the `epson-scan` flake check has a native-tone case: the stock
  test batch, converted to native tone, routes the same, and only the photo is
  tagged, with its pixels unchanged. `scan-classify`'s self-test covers
  `--classify-lut` and `--icc-profile`. Tonight's real native scans (the card
  three times, the reference print twice) route as the stock driver routed them.
  The print crops to 6.08 × 8.04 in.
- **Owner ruling: the card is the reference.** Trust the measured card over
  judging single prints by eye or phone photo. See "Metamerism" for the known
  limit of that choice.

- **Ingestion live (2026-11-07).** Both keys are in agenix
  (`.secrets/hosts/bitstream/scanning/`) and loaded by epson-scan.
  - paperless: the token authenticates (HTTP 200 on the documents API, read-only
    check). No real document has been sent yet.
  - immich: tested end to end with the reference print, scanned through the
    native-tone driver and run through the deployed `scan-classify` and
    `epson-scan-retry`. It routed blank + photo, uploaded, and immich created
    the `Scans` album.
  - The stored original keeps the embedded profile byte for byte.
  - immich honours it: its preview matches the scan converted through
    `ff-680w.icc` to sRGB within 0.2 L\* on every region measured, and differs
    from the raw pixels by up to 11 L\*. Its EXIF view does not list the profile
    name; that is cosmetic.

### Remaining work

1. **Rotate the immich key** once everything has been confirmed working: it was
   pasted into a chat session, and it has every permission. Replace it with one
   limited to `asset.upload`, `album.read`, `album.create` and
   `albumAsset.create` ("Adding the upload keys", step 2).
2. **The held batches.** On 2026-11-07 every batch was moved out of the spool to
   `/var/lib/private/epson-scan/held/` on bitstream, so no key can upload them:
   - `20261104-205023`, `-205035`, `-205124`: empty (no `routes`; aborted
     scans);
   - `20261104-211302`, `-212256`, `20261105-154831`: one photo each, scanned
     with the stock driver, untagged;
   - `20261106-170417`, `20261106-172929`: the colour card, not for immich.

   Rescan the three photos (button press as usual), check the new batches, then
   delete `held/`. To send an old batch as it is, move it back to `spool/` and
   run `systemctl start epson-scan-retry`.

## Adding the upload keys

Each app issues its own, and `services.scanning.epson` picks up whichever file
exists. On cortex, in the repository:

1. Issue the key:
   - **paperless:** Profile → API Auth Token.
   - **immich:** Account Settings → API Keys, with the permissions
     `asset.upload`, `album.read` and `albumAsset.create`.
2. Encrypt it to the master identity. `agenix edit -i` needs a regular file, so
   use a private one on the RAM-backed runtime directory and shred it after:
   `umask 077; f=$(mktemp -p "$XDG_RUNTIME_DIR"); wl-paste > "$f";`
   `agenix edit -i "$f" .secrets/hosts/bitstream/scanning/immich-api-key.age; shred -u "$f"`
   (or `paperless-token.age`). Never paste a key into a chat or a shell command.
3. Run `agenix rekey -a`, then
   `git add .secrets/hosts/bitstream/scanning .secrets/hosts/bitstream/rekeyed`
   (agenix-rekey refuses a file that is not in git).
4. Commit, push and deploy bitstream. The hourly `epson-scan-retry` then sends
   whatever the spool holds, or start it at once with
   `systemctl start epson-scan-retry`.

## Re-profiling

After a firmware update, or to check drift: scan the card through epson-scan's
own driver from cortex (below), read it (`tools/grid.py` locates the patch
grid), compare with
`profcheck -k card.ti3 modules/den/aspects/services/scanning/ff-680w.icc`, and
rebuild if the average error has risen. Average several scans with
`tools/repeat.py`.

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
are dyes. On the reference print (a family snapshot) a grey-brown stone wall
reads green to the scanner (a\* −8 to −10 on the native scan), and the full card
profile pushes it slightly further. The owner's ruling (above) is to trust the
card regardless. If dye prints prove systematically off across many photos, the
cheap fix is a dye-based target: a ~300-patch chart image printed at a photo lab
(Costco, auto-correction off), profiled against the file's own values. An
IT8.7/2 target on photo paper does the same job properly but costs far more.

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
