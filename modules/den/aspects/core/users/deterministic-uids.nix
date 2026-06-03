# Deterministic UIDs/GIDs — consistent IDs across all hosts for NFS and service accounts.
#
# Ported from main:modules/_legacy/core/deterministic-uids/
# The option module defines `users.deterministicIds` which auto-assigns uid/gid
# to users/groups via mkDefault. The data module provides the central ID registry.
{
  den.aspects.core.users.deterministic-uids = {
    nixos =
      { config, lib, ... }:
      let
        inherit (lib)
          mkDefault
          mkIf
          mkOption
          types
          concatLists
          flip
          mapAttrsToList
          ;

        cfg = config.users.deterministicIds;

        uidGid = id: {
          uid = id;
          gid = id;
        };
      in
      {
        options.users = {
          deterministicIds = mkOption {
            default = { };
            description = "Maps user/group name to expected uid/gid values.";
            type = types.attrsOf (
              types.submodule {
                options = {
                  uid = mkOption {
                    type = types.nullOr types.int;
                    default = null;
                  };
                  gid = mkOption {
                    type = types.nullOr types.int;
                    default = null;
                  };
                  subUidRanges = mkOption {
                    type = types.listOf (
                      types.submodule {
                        options = {
                          startUid = mkOption { type = types.int; };
                          count = mkOption { type = types.int; };
                        };
                      }
                    );
                    default = [ ];
                  };
                  subGidRanges = mkOption {
                    type = types.listOf (
                      types.submodule {
                        options = {
                          startGid = mkOption { type = types.int; };
                          count = mkOption { type = types.int; };
                        };
                      }
                    );
                    default = [ ];
                  };
                };
              }
            );
          };

          users = mkOption {
            type = types.attrsOf (
              types.submodule (
                { name, ... }:
                {
                  config = {
                    uid =
                      let
                        v = cfg.${name}.uid or null;
                      in
                      mkIf (v != null) (mkDefault v);
                    subUidRanges =
                      let
                        v = cfg.${name}.subUidRanges or [ ];
                      in
                      mkIf (v != [ ]) (mkDefault v);
                    subGidRanges =
                      let
                        v = cfg.${name}.subGidRanges or [ ];
                      in
                      mkIf (v != [ ]) (mkDefault v);
                  };
                }
              )
            );
          };

          groups = mkOption {
            type = types.attrsOf (
              types.submodule (
                { name, ... }:
                {
                  config.gid =
                    let
                      v = cfg.${name}.gid or null;
                    in
                    mkIf (v != null) (mkDefault v);
                }
              )
            );
          };
        };

        config.users.deterministicIds = {
          systemd-oom = uidGid 999;
          systemd-coredump = uidGid 998;
          sshd = uidGid 997;
          nscd = uidGid 996;
          polkituser = uidGid 995;
          microvm = uidGid 994;
          podman = uidGid 993;
          avahi = uidGid 992;
          colord = uidGid 991;
          geoclue = uidGid 990;
          gnome-remote-desktop = uidGid 989;
          rtkit = uidGid 988;
          nm-iodine = uidGid 987;
          openrazer = uidGid 986;
          resolvconf = uidGid 985;
          fwupd-refresh = uidGid 984;
          adbusers = uidGid 983;
          msr = uidGid 982;
          gamemode = uidGid 981;
          greeter = uidGid 980;
          uinput = uidGid 979;
          frr = uidGid 978;
          frrvty = uidGid 977;
          acme = uidGid 976;
          nginx = uidGid 975;
          kanidm = uidGid 974;
          node-exporter = uidGid 973;
          grafana = uidGid 972;
          loki = uidGid 971;
          promtail = uidGid 970;
          vault = uidGid 969;
          wireshark = uidGid 968;
          i2c = uidGid 967;
          tss = uidGid 966;
          alloy = uidGid 965;
          docker = uidGid 964;
          tang = uidGid 963;
          ollama = uidGid 962;
          open-webui = uidGid 961;
          gnome-initial-setup = uidGid 960;
          wpa_supplicant = uidGid 959;
          oauth2-proxy = uidGid 958;
          headscale = uidGid 957;
          nix-remote-build = uidGid 956;
          haproxy = uidGid 955;
          pcscd = uidGid 954;
          atticd = uidGid 953;
          git = uidGid 952;
          jellyfin = uidGid 1027;
          process-exporter = uidGid 948;

          system-access = {
            gid = 951;
          };
          workstation-access = {
            gid = 950;
          };
          server-access = {
            gid = 949;
          };
        };

        config.assertions =
          concatLists (
            flip mapAttrsToList config.users.users (
              name: user: [
                {
                  assertion = user.uid != null;
                  message = "den: non-deterministic uid for '${name}', assign via users.deterministicIds";
                }
                {
                  assertion = !user.autoSubUidGidRange;
                  message = "den: non-deterministic subUids/subGids for: ${name}";
                }
              ]
            )
          )
          ++ flip mapAttrsToList config.users.groups (
            name: group: {
              assertion = group.gid != null;
              message = "den: non-deterministic gid for '${name}', assign via users.deterministicIds";
            }
          );
      };
  };
}
