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
# the spool (/var/lib/private/epson-scan/spool/<stamp>); epson-scan-retry
# re-delivers it hourly (or `systemctl start epson-scan-retry`), sending only the
# destinations not yet done. The scripts are _epson-scan.nix; epson-scan-check.nix
# runs them against a stand-in scanner and upload clients.
#
# Runs on a host on the scanner's own network: the call is link-local multicast.
# Only the scanner's address may reach UDP 2968.
# TODO: with a second scanner, or a generic classify-and-file endpoint, split it:
# the listener stays here and calls the cluster, where batch/deliver run as a
# service reaching the scanner over TCP 1865 (as prod already can, like ninfer).
#
# Tokens are issued by each app, not generated (encrypt to the master key, then
# `agenix rekey`):
#   paperless   Profile -> API Auth Token  -> <host secrets>/scanning/paperless-token.age
#   immich      Account Settings -> API Keys (asset.upload, album.read,
#               albumAsset.create) -> <host secrets>/scanning/immich-api-key.age
# Until a file exists its destination is off and its batches stay spooled.
#
# Colour: the stock epsonds driver treats the FF-680W as a document scanner and clips
# its tone; nativeTone scans through a patched driver, and iccProfile tags each photo
# with a profile measured from a ColorChecker (docs/scanner-color/,
# docs/runbooks/scanner-color-profile.md).
{ lib, ... }:
let
  stateDir = "epson-scan";
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
      photoRotation = lib.mkOption {
        type = lib.types.enum [
          0
          90
          180
          270
        ];
        default = 180;
        description = ''
          Clockwise turn applied to each photo's picture side. Prints fed the way
          they were set up come out upside down; documents are left alone, as
          paperless rotates its pages itself during OCR.
        '';
      };
      nativeTone = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Scan through sane-backends patched to give the FF-680W identity tone curves
          (_sane-ff680w-native-tone.patch) instead of the DS-530 document curves the
          stock driver uploads, which crush the shadows and clip the highlights. Pages
          are classified through the stock curve, so routing is unchanged.
        '';
      };
      iccProfile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = ./ff-680w.icc;
        description = ''
          ICC profile assigned (not converted) to each photo and back page before
          upload. The default is measured from a ColorChecker through the native-tone
          driver (docs/scanner-color/), so it is valid only with nativeTone.
        '';
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
        # The FF-680W's own tone, unclipped (see nativeTone).
        sane = pkgs.sane-backends.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./_sane-ff680w-native-tone.patch ];
        });
        scripts = import ./_epson-scan.nix {
          inherit lib pkgs cfg;
          inherit (pkgs.local) scan-classify;
          tools = lib.optionalAttrs cfg.nativeTone { sane-backends = sane; };
        };
        tokenFile = name: host.secretPath + "/scanning/${name}.age";
        # agenix-rekey refuses a rekeyFile that is not in git.
        present = lib.filterAttrs (_: name: builtins.pathExists (tokenFile name)) scripts.tokens;

        # Only epsonds, pointed at the scanner: no USB or mDNS probing.
        saneConfig = pkgs.linkFarm "epson-scan-sane" {
          "dll.conf" = pkgs.writeText "dll.conf" "epsonds\n";
          "epsonds.conf" = pkgs.writeText "epsonds.conf" "net ${cfg.scanner}\n";
        };

        # Both units: one dynamic user (shared by name), so both own the spool.
        sandbox = {
          DynamicUser = true;
          User = "epson-scan";
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
        # The spool is an impermanence bind mount: start after it, or the service
        # writes under the mount point and the mount then hides its state dir.
        unitConfig.RequiresMountsFor = [ "/var/lib/private/${stateDir}" ];
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
          inherit unitConfig;
          environment.SANE_CONFIG_DIR = "${saneConfig}";
          serviceConfig = sandbox // {
            ExecStart = "${lib.getExe scripts.listener} ${cfg.scanner} ${lib.getExe scripts.batch}";
            Restart = "on-failure";
          };
        };

        systemd.services.epson-scan-retry = {
          description = "Re-deliver kept Epson scan batches";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          inherit unitConfig;
          serviceConfig = sandbox // {
            Type = "oneshot";
            ExecStart = lib.getExe scripts.retry;
          };
        };
        systemd.timers.epson-scan-retry = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "hourly";
            RandomizedDelaySec = "5m";
          };
        };
      };

    # Batches that could not be uploaded survive restarts and reboots.
    persist.directories = [ "/var/lib/private/${stateDir}" ];
  };
}
