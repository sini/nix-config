# The scripts of services.scanning.epson (epson.nix), apart so epson-scan-check.nix
# can run them against stand-ins for the scanner and the upload clients (`tools`).
#
#   batch    scan the loaded batch into a new spool dir, route it, deliver it
#   deliver  upload spool dirs; a destination done is marked, so a retry never
#            sends it twice; a dir is removed once every destination is done
#   retry    deliver every spool dir (epson-scan-retry.service, hourly)
#   listener wait for the scan button and run batch per press
{
  lib,
  pkgs,
  cfg,
  scan-classify,
  tools ? { },
}:
let
  t = {
    inherit (pkgs) sane-backends curl immich-cli;
  }
  // tools;
  # Native tone (the patched driver): judge pages through the stock driver's curve, so
  # the feed band and the classifier's thresholds hold; the pages keep their pixels.
  classifyFlags = lib.concatStringsSep " " (
    lib.optional (cfg.nativeTone or false)
      "--classify-lut ${scan-classify}/share/scan-classify/epsonds-lut2.csv"
    ++ lib.optional ((cfg.iccProfile or null) != null) "--icc-profile ${cfg.iccProfile}"
  );
  tokens = {
    paperless = "paperless-token";
    immich = "immich-api-key";
  };

  deliver = pkgs.writeShellApplication {
    name = "epson-scan-deliver";
    runtimeInputs = [
      t.curl
      t.immich-cli
      pkgs.img2pdf
      pkgs.gawk
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      # Unset when no token exists yet: then every destination is off.
      creds=''${CREDENTIALS_DIRECTORY:-/nonexistent}
      status=0
      for dir in "$@"; do
        dir=$(realpath "$dir")
        # No routes yet: the batch is still scanning.
        [ -f "$dir/routes" ] || continue
        (
          cd "$dir"
          exec 9> .lock
          flock -n 9 || { echo "$dir: busy"; exit 0; }
          stamp=$(basename "$dir")
          mapfile -t photos < <(awk '$1 == "photo" || $1 == "back" { print $2 }' routes)
          mapfile -t documents < <(awk '$1 == "document" { print $2 }' routes)
          mapfile -t review < <(awk '$1 == "review" { print $2 }' routes)
          kept=0
          failed=0
          # Every page not blank must be in a list, or nothing is sent and the
          # batch is kept.
          if [ "$(awk '$1 != "blank"' routes | wc -l)" -ne $((''${#photos[@]} + ''${#documents[@]} + ''${#review[@]})) ]; then
            echo "$stamp: routes and pages disagree, keeping $dir"
            exit 1
          fi

          paperless() { # <part> <title> <pages...>
            part=$1 title=$2
            shift 2
            [ $# -gt 0 ] && [ ! -e ".done-$part" ] || return 0
            if [ ! -r "$creds/${tokens.paperless}" ]; then
              echo "$stamp: paperless: no token, keeping $part"
              kept=1
              return 0
            fi
            img2pdf "$@" -o "$title.pdf"
            if curl -fsS -H "Authorization: Token $(cat "$creds/${tokens.paperless}")" \
                -F "document=@$title.pdf" -F "title=$title" \
                "${cfg.paperlessUrl}/api/documents/post_document/" > /dev/null; then
              touch ".done-$part"
              echo "$stamp: paperless: uploaded $title ($# pages)"
            else
              echo "$stamp: paperless: upload of $title failed"
              kept=1
              failed=1
            fi
          }
          paperless documents "scan-$stamp" "''${documents[@]}"
          paperless review "scan-$stamp-needs-review" "''${review[@]}"

          if [ ''${#photos[@]} -gt 0 ] && [ ! -e .done-photos ]; then
            if [ ! -r "$creds/${tokens.immich}" ]; then
              echo "$stamp: immich: no API key, keeping ''${#photos[@]} photos"
              kept=1
            elif HOME=$(mktemp -d) IMMICH_INSTANCE_URL="${cfg.immichUrl}/api" \
                IMMICH_API_KEY="$(cat "$creds/${tokens.immich}")" \
                immich upload --album-name ${lib.escapeShellArg cfg.album} "''${photos[@]}"; then
              touch .done-photos
              echo "$stamp: immich: uploaded ''${#photos[@]} photos"
            else
              echo "$stamp: immich: upload failed"
              kept=1
              failed=1
            fi
          fi

          if [ "$kept" = 1 ]; then
            echo "kept $dir"
            exit "$failed"
          fi
          cd /
          rm -r "$dir"
        ) || status=1
      done
      exit "$status"
    '';
  };

  batch = pkgs.writeShellApplication {
    name = "epson-scan-batch";
    runtimeInputs = [
      t.sane-backends
      scan-classify
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
    ];
    text = ''
      stamp=$(date +%Y%m%d-%H%M%S)
      dir="$STATE_DIRECTORY/spool/$stamp"
      mkdir -p "$dir"
      cd "$dir"

      # Right after the button the scanner is still looking for Epson's app and
      # fails the scan with a device I/O error; it accepts within ~15s.
      shopt -s nullglob
      for _ in $(seq 15); do
        rm -f -- "$stamp"-*.png
        if scanimage -d "epsonds:net:${cfg.scanner}" --source "ADF Duplex" --mode Color \
            --resolution ${toString cfg.resolution} --adf-skew=yes \
            --format png --batch="$stamp-%03d.png" 2> scan.log; then
          break
        fi
        grep -q "out of documents" scan.log && break
        sleep 3
      done
      tail -n 2 scan.log
      pages=("$stamp"-*.png)
      if [ ''${#pages[@]} -eq 0 ]; then
        echo "no pages scanned (feeder empty?)"
        cd /
        rm -r "$dir"
        exit 0
      fi

      scan-classify --dpi ${toString cfg.resolution} --duplex --trim-in-place \
        --photo-rotate ${toString cfg.photoRotation} ${classifyFlags} "''${pages[@]}" > routes.tmp
      mv routes.tmp routes
      echo "routed ''${#pages[@]} pages: $(cut -d' ' -f1 routes | sort | uniq -c | awk '{ printf "%s%s %s", sep, $1, $2; sep = " " }')"
      exec ${lib.getExe deliver} "$dir"
    '';
  };

  retry = pkgs.writeShellApplication {
    name = "epson-scan-retry";
    text = ''
      shopt -s nullglob
      dirs=("$STATE_DIRECTORY"/spool/*/)
      [ ''${#dirs[@]} -eq 0 ] || exec ${lib.getExe deliver} "''${dirs[@]}"
    '';
  };

  listener = pkgs.writers.writePython3Bin "epson-scan" { } ''
    import socket
    import struct
    import subprocess
    import sys

    GROUP, PORT, SCANNER = "239.255.255.253", 2968, sys.argv[1]
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("", PORT))
    group = socket.inet_aton(GROUP)
    mreq = struct.pack("4s4s", group, socket.inet_aton("0.0.0.0"))
    s.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
    print(f"waiting for {SCANNER}'s scan button", flush=True)
    while True:
        _, (src, _) = s.recvfrom(2048)
        if src != SCANNER:
            continue
        print("scan button pressed", flush=True)
        subprocess.run([sys.argv[2]], check=False)
        # Calls queued while scanning are the same press repeated.
        s.setblocking(False)
        try:
            while s.recv(2048):
                pass
        except BlockingIOError:
            pass
        s.setblocking(True)
  '';
in
{
  inherit
    tokens
    batch
    deliver
    retry
    listener
    ;
}
