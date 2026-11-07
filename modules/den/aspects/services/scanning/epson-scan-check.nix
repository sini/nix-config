# epson-scan-check: services.scanning.epson's scripts (_epson-scan.nix), run
# against a stand-in scanner and upload clients:
#   no tokens        the batch is routed and kept; nothing is sent
#   scanner busy     the first scan fails as the scanner does right after its
#                    button; the retry scans, both destinations upload, the
#                    batch is removed
#   immich down      paperless uploads and is marked; immich fails and the batch
#                    is kept; retry later sends only the photos
#   empty feeder     no pages, no batch
#   nothing kept     retry with an empty spool succeeds
#   native tone      the same batch in the patched driver's tone routes the same,
#                    and the photo (only) carries the ICC profile, pixels unchanged
#   nix build .#checks.x86_64-linux.epson-scan
{ lib, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    lib.optionalAttrs (system == "x86_64-linux") (
      let
        # Records each call, one line per call, in $FAKE/calls.
        recorder =
          name: rcVar:
          pkgs.writeShellScriptBin name ''
            echo "${name} $*" >> "$FAKE/calls"
            exit "''${${rcVar}:-0}"
          '';
        # Copies $FAKE_PAGES/*.png to the --batch pattern; fails the first
        # $FAKE_SCAN_FAILS calls as the scanner does while it looks for Epson's app.
        scanimage = pkgs.writeShellScriptBin "scanimage" ''
          n=$(( $(cat "$FAKE/scans" 2>/dev/null || echo 0) + 1 ))
          echo "$n" > "$FAKE/scans"
          if [ "$n" -le "''${FAKE_SCAN_FAILS:-0}" ]; then
            echo "scanimage: sane_get_parameters: Error during device I/O" >&2
            exit 1
          fi
          for a; do case $a in --batch=*) pattern=''${a#--batch=} ;; esac; done
          i=1
          for p in "$FAKE_PAGES"/*.png; do
            [ -e "$p" ] || continue
            cp "$p" "$(printf "$pattern" "$i")"
            i=$((i + 1))
          done
          echo "scanimage: sane_start: Document feeder out of documents" >&2
        '';
        # Small pages: content decides the routes, not resolution.
        cfg = {
          scanner = "192.0.2.1";
          resolution = 50;
          paperlessUrl = "https://paperless.test";
          immichUrl = "https://immich.test";
          album = "Scans";
          photoRotation = 180;
        };
        tools = {
          sane-backends = scanimage;
          curl = recorder "curl" "FAKE_CURL_RC";
          immich-cli = recorder "immich" "FAKE_IMMICH_RC";
        };
        scripts = import ./_epson-scan.nix {
          inherit
            lib
            pkgs
            cfg
            tools
            ;
          inherit (config.packages) scan-classify;
        };
        icc = ./ff-680w.icc;
        native = import ./_epson-scan.nix {
          inherit lib pkgs tools;
          inherit (config.packages) scan-classify;
          cfg = cfg // {
            nativeTone = true;
            iccProfile = icc;
          };
        };
        python = pkgs.python3.withPackages (p: [ p.pillow ]);
      in
      {
        checks.epson-scan = pkgs.runCommand "epson-scan-check" { nativeBuildInputs = [ python ]; } ''
          set -euo pipefail
          # One duplex batch shaped like the FF-680W's: a print (blank back
          # first) and a letter page (blank back).
          mkdir -p pages empty
          LUT=${config.packages.scan-classify}/share/scan-classify/epsonds-lut2.csv python3 - <<'EOF'
          from PIL import Image, ImageDraw
          DPI, BAND = 50, (200, 210, 218)
          def scan(item, back=False):
              w, band = int(8.48 * DPI), item.height + int(0.4 * DPI)
              page = Image.new("RGB", (w, band + 2 * DPI), (255, 255, 255))
              page.paste(BAND, (0, 0, w, band))
              page.paste(item, ((w - item.width) // 2, 0))
              if back:
                  page.paste((254, 255, 252), (0, 0, int(0.15 * DPI), band))
              return page
          hues = Image.linear_gradient("L").resize((6 * DPI, 4 * DPI))
          sv = Image.new("L", hues.size, 200)
          photo = Image.merge("HSV", (hues, sv, sv)).convert("RGB")
          letter = Image.new("RGB", (int(8.5 * DPI), 11 * DPI), (255, 255, 255))
          draw = ImageDraw.Draw(letter)
          for y in range(20, letter.height - 20, 15):
              draw.rectangle((20, y, letter.width - 20, y + 2), fill=(20, 20, 20))
          blank = lambda w, h: Image.new("RGB", (int(w * DPI), int(h * DPI)), (255, 255, 255))
          scan(blank(6, 4), back=True).save("pages/1.png")
          scan(photo).save("pages/2.png")
          scan(letter).save("pages/3.png")
          scan(blank(8.5, 11), back=True).save("pages/4.png")
          # The same pages as the patched driver returns them: the stock curve undone.
          import os
          rows = [list(map(int, l.split(","))) for l in open(os.environ["LUT"]).read().splitlines()[1:]]
          inverse = []
          for c in (1, 2, 3):
              for v in range(256):
                  hits = [r[0] for r in rows if r[c] == v]
                  inverse.append((hits[0] + hits[-1]) // 2 if hits else next(r[0] for r in rows if r[c] >= v))
          os.makedirs("native-pages")
          for n in "1234":
              Image.open(f"pages/{n}.png").point(inverse).save(f"native-pages/{n}.png")
          EOF

          # An empty PATH: the scripts must carry every tool they use, as a
          # service's PATH (coreutils, grep, sed, findutils) does not.
          batch() { PATH=/var/empty ${lib.getExe scripts.batch}; }
          native-batch() { PATH=/var/empty ${lib.getExe native.batch}; }
          retry() { PATH=/var/empty ${lib.getExe scripts.retry}; }
          fail() { echo "FAIL $case: $*"; cat "$case/log" 2>/dev/null; exit 1; }
          setup() {
            case=$1
            export STATE_DIRECTORY=$PWD/$case/state FAKE=$PWD/$case/fake FAKE_PAGES=$PWD/pages
            mkdir -p "$STATE_DIRECTORY" "$FAKE"
            touch "$FAKE/calls"
            unset CREDENTIALS_DIRECTORY FAKE_SCAN_FAILS FAKE_CURL_RC FAKE_IMMICH_RC
          }
          tokens() {
            export CREDENTIALS_DIRECTORY=$PWD/$case/creds
            mkdir -p "$CREDENTIALS_DIRECTORY"
            echo paperless-secret > "$CREDENTIALS_DIRECTORY/paperless-token"
            echo immich-secret > "$CREDENTIALS_DIRECTORY/immich-api-key"
          }
          batches() { find "$STATE_DIRECTORY/spool" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l; }
          calls() { grep -c "^$1 " "$FAKE/calls" || true; }

          setup no-tokens
          batch > "$case/log" 2>&1
          grep -q "routed 4 pages: 2 blank 1 document 1 photo" "$case/log" || fail "routes"
          grep -q "paperless: no token, keeping documents" "$case/log" || fail "paperless not kept"
          grep -q "immich: no API key, keeping 1 photos" "$case/log" || fail "immich not kept"
          [ "$(batches)" = 1 ] || fail "batch not kept"
          [ ! -s "$FAKE/calls" ] || fail "sent without tokens"

          setup scanner-busy
          tokens
          export FAKE_SCAN_FAILS=1
          batch > "$case/log" 2>&1
          [ "$(cat "$FAKE/scans")" = 2 ] || fail "expected 2 scan attempts"
          [ "$(calls curl)" = 1 ] || fail "expected 1 paperless upload"
          grep -q "post_document" "$FAKE/calls" || fail "paperless endpoint"
          grep -q "^immich upload --album-name Scans .*-002.png$" "$FAKE/calls" || fail "immich upload of the print"
          [ "$(batches)" = 0 ] || fail "batch not removed"

          setup immich-down
          tokens
          export FAKE_IMMICH_RC=1
          batch > "$case/log" 2>&1 || true
          [ "$(batches)" = 1 ] || fail "batch not kept"
          [ -e "$STATE_DIRECTORY"/spool/*/.done-documents ] || fail "paperless not marked done"
          export FAKE_IMMICH_RC=0
          retry >> "$case/log" 2>&1
          [ "$(calls curl)" = 1 ] || fail "retry re-sent paperless"
          [ "$(calls immich)" = 2 ] || fail "retry did not send the photos"
          [ "$(batches)" = 0 ] || fail "batch not removed after retry"

          setup empty-feeder
          export FAKE_PAGES=$PWD/empty
          batch > "$case/log" 2>&1
          grep -q "no pages scanned" "$case/log" || fail "no pages not reported"
          [ "$(batches)" = 0 ] || fail "empty batch kept"

          setup nothing-kept
          retry > "$case/log" 2>&1 || fail "retry on an empty spool failed"

          setup native-tone
          export FAKE_PAGES=$PWD/native-pages
          native-batch > "$case/log" 2>&1
          grep -q "routed 4 pages: 2 blank 1 document 1 photo" "$case/log" || fail "native routes"
          spool=$(echo "$STATE_DIRECTORY"/spool/*)
          photo=$(awk '$1 == "photo" { print $2 }' "$spool/routes")
          doc=$(awk '$1 == "document" { print $2 }' "$spool/routes")
          python3 - "$spool/$photo" "$spool/$doc" ${icc} native-pages/2.png <<'EOF' || fail "ICC tagging"
          import sys
          from PIL import Image
          photo, doc, icc, source = sys.argv[1:]
          p = Image.open(photo)
          assert p.info.get("icc_profile") == open(icc, "rb").read(), "photo not tagged"
          assert Image.open(doc).info.get("icc_profile") is None, "document tagged"
          # Pixels unchanged: the photo's centre is the native print's centre (the
          # print sits top-centre, 6x4in at 50dpi; turning it 180 moves the centre by
          # at most a pixel).
          s = Image.open(source).convert("RGB")
          c = p.convert("RGB").getpixel((p.width // 2, p.height // 2))
          near = {s.getpixel((s.width // 2 + dx, 100 + dy)) for dx in (-1, 0) for dy in (-1, 0)}
          assert c in near, f"pixel changed: {c} not in {near}"
          EOF

          echo "epson-scan: all cases passed"
          touch $out
        '';
      }
    );
}
