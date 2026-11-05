# Epson network scanner (FF-680W) -> immich and paperless, from its scan button.
#
# The button makes the scanner multicast a push-scan call (UDP 2968 to
# 239.255.255.253) looking for Epson's desktop app; nothing answers, so it
# flashes an orange `!`, and refuses network scans for some seconds while it looks.
# epson-scan joins that group and, on each call, scans the loaded batch over
# epsonds (scanimage, TCP 1865: duplex, skew correction; the scanner ignores
# --adf-crp), retrying until the scanner accepts. scan-classify crops each page to
# its item and routes it, and the batch is uploaded:
#   photo, back   immich, into the `album` (backs beside their fronts)
#   document      paperless, one PDF per batch
#   review        paperless, one PDF titled for review
#   blank         dropped
# A batch whose upload fails, or whose destination has no token yet, stays in
# the spool (/var/lib/private/epson-scan/spool/<stamp>) for a later retry by hand.
#
# Runs on a host on the scanner's own network: the call is link-local multicast.
# Only the scanner's address may reach UDP 2968.
#
# Tokens are issued by each app, not generated (encrypt to the master key, then
# `agenix rekey`):
#   paperless   Profile -> API Auth Token  -> <host secrets>/scanning/paperless-token.age
#   immich      Account Settings -> API Keys (asset.upload, album.read,
#               albumAsset.create) -> <host secrets>/scanning/immich-api-key.age
# Until a file exists its destination is off and its batches stay spooled.
{ lib, ... }:
let
  stateDir = "epson-scan";
  tokens = {
    paperless = "paperless-token";
    immich = "immich-api-key";
  };
in
{
  den.aspects.services.scanning.epson = {
    settings = {
      scanner = lib.mkOption {
        type = lib.types.str;
        description = "The scanner's IPv4 address (a DHCP reservation).";
      };
      resolution = lib.mkOption {
        type = lib.types.enum [
          300
          600
        ];
        default = 600;
        description = "Scan resolution in dpi; 300 quarters the size at half the detail.";
      };
      paperlessUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://paperless.json64.dev";
        description = "paperless-ngx base URL.";
      };
      immichUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://immich.json64.dev";
        description = "immich base URL.";
      };
      album = lib.mkOption {
        type = lib.types.str;
        default = "Scans";
        description = "immich album scanned photos are added to.";
      };
    };

    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        cfg = host.settings.services.scanning.epson;
        tokenFile = name: host.secretPath + "/scanning/${name}.age";
        # agenix-rekey refuses a rekeyFile that is not in git.
        present = lib.filterAttrs (_: name: builtins.pathExists (tokenFile name)) tokens;

        # Only epsonds, pointed at the scanner: no USB or mDNS probing.
        saneConfig = pkgs.linkFarm "epson-scan-sane" {
          "dll.conf" = pkgs.writeText "dll.conf" "epsonds\n";
          "epsonds.conf" = pkgs.writeText "epsonds.conf" "net ${cfg.scanner}\n";
        };

        batch = pkgs.writeShellApplication {
          name = "epson-scan-batch";
          runtimeInputs = [
            pkgs.sane-backends
            pkgs.local.scan-classify
            pkgs.img2pdf
            pkgs.immich-cli
            pkgs.curl
            pkgs.coreutils
            pkgs.gawk
          ];
          text = ''
            # Unset when no token exists yet: then every destination is off.
            creds=''${CREDENTIALS_DIRECTORY:-/nonexistent}
            spool="$STATE_DIRECTORY/spool"
            dir="$spool/$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$dir"
            cd "$dir"

            # Right after the button the scanner is still looking for Epson's app and
            # fails the scan with a device I/O error; it accepts within ~15s.
            shopt -s nullglob
            for _ in $(seq 15); do
              rm -f page-*.png
              if scanimage -d "epsonds:net:${cfg.scanner}" --source "ADF Duplex" --mode Color \
                  --resolution ${toString cfg.resolution} --adf-skew=yes \
                  --format png --batch=page-%03d.png 2> scan.log; then
                break
              fi
              grep -q "out of documents" scan.log && break
              sleep 3
            done
            tail -n 2 scan.log
            pages=(page-*.png)
            if [ ''${#pages[@]} -eq 0 ]; then
              echo "no pages scanned (feeder empty?)"
              rmdir "$dir"
              exit 0
            fi

            scan-classify --dpi ${toString cfg.resolution} --duplex --trim-in-place "''${pages[@]}" > routes
            echo "routed ''${#pages[@]} pages: $(cut -d' ' -f1 routes | sort | uniq -c | tr -s ' \n' ' ')"

            mapfile -t photos < <(awk '$1 == "photo" || $1 == "back" { print $2 }' routes)
            mapfile -t documents < <(awk '$1 == "document" { print $2 }' routes)
            mapfile -t review < <(awk '$1 == "review" { print $2 }' routes)
            ok=1
            # Every page not blank must be in a list, or the batch is kept.
            if [ "$(awk '$1 != "blank"' routes | wc -l)" -ne $((''${#photos[@]} + ''${#documents[@]} + ''${#review[@]})) ]; then
              echo "routes and pages disagree"; ok=0
            fi

            paperless() { # <title> <pages...>
              title=$1; shift
              [ $# -gt 0 ] || return 0
              if [ ! -r "$creds/${tokens.paperless}" ]; then
                echo "paperless: no token, keeping $title"; ok=0; return 0
              fi
              img2pdf "$@" -o "$title.pdf"
              if curl -fsS -H "Authorization: Token $(cat "$creds/${tokens.paperless}")" \
                  -F "document=@$title.pdf" -F "title=$title" \
                  "${cfg.paperlessUrl}/api/documents/post_document/" > /dev/null; then
                echo "paperless: uploaded $title ($# pages)"
              else
                echo "paperless: upload of $title failed"; ok=0
              fi
            }
            stamp=$(basename "$dir")
            paperless "scan-$stamp" "''${documents[@]}"
            paperless "scan-$stamp-needs-review" "''${review[@]}"

            if [ ''${#photos[@]} -gt 0 ]; then
              if [ ! -r "$creds/${tokens.immich}" ]; then
                echo "immich: no API key, keeping ''${#photos[@]} photos"; ok=0
              else
                for i in "''${!photos[@]}"; do
                  mv "''${photos[$i]}" "$stamp-$(printf %03d "$i").png"
                  photos[i]="$stamp-$(printf %03d "$i").png"
                done
                if HOME="$dir" IMMICH_INSTANCE_URL="${cfg.immichUrl}/api" \
                    IMMICH_API_KEY="$(cat "$creds/${tokens.immich}")" \
                    immich upload --album-name ${lib.escapeShellArg cfg.album} "''${photos[@]}"; then
                  echo "immich: uploaded ''${#photos[@]} photos"
                else
                  echo "immich: upload failed"; ok=0
                fi
              fi
            fi

            if [ "$ok" = 1 ]; then rm -r "$dir"; else echo "kept $dir"; fi
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
        age.secrets = lib.mapAttrs' (
          _: name: lib.nameValuePair "scanning-${name}" { rekeyFile = tokenFile name; }
        ) present;

        networking.firewall.extraInputRules = ''
          ip saddr ${cfg.scanner} udp dport 2968 accept comment "epson-scan button"
        '';

        systemd.services.epson-scan = {
          description = "Scan from the Epson scanner's button into immich and paperless";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          environment.SANE_CONFIG_DIR = "${saneConfig}";
          serviceConfig = {
            ExecStart = "${lib.getExe listener} ${cfg.scanner} ${lib.getExe batch}";
            Restart = "on-failure";
            DynamicUser = true;
            StateDirectory = stateDir;
            LoadCredential = lib.mapAttrsToList (
              _: name: "${name}:${config.age.secrets."scanning-${name}".path}"
            ) present;
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictNamespaces = true;
            LockPersonality = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
          };
        };
      };

    # Batches that could not be uploaded survive restarts and reboots.
    persist.directories = [ "/var/lib/private/${stateDir}" ];
  };
}
