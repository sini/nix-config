{ den, lib, ... }:
{
  den.aspects.deterministic-uids = {
    includes = lib.attrValues den.aspects.deterministic-uids._;

    _ = {
      options = den.lib.perHost {
        nixos =
          { config, ... }:
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
          in
          {
            options = {
              users = {
                deterministicIds = mkOption {
                  default = { };
                  description = ''
                    Maps a user or group name to its expected uid/gid values. If a user/group is
                    used on the system without specifying a uid/gid, this module will assign the
                    corresponding ids defined here, or show an error if the definition is missing.
                  '';
                  type = types.attrsOf (
                    types.submodule {
                      options = {
                        uid = mkOption {
                          type = types.nullOr types.int;
                          default = null;
                          description = "The uid to assign if it is missing in `users.users.<name>`.";
                        };
                        gid = mkOption {
                          type = types.nullOr types.int;
                          default = null;
                          description = "The gid to assign if it is missing in `users.groups.<name>`.";
                        };
                        subUidRanges = mkOption {
                          type = types.listOf (
                            types.submodule {
                              options = {
                                startUid = mkOption {
                                  type = types.int;
                                  description = "The starting uid for the range.";
                                };
                                count = mkOption {
                                  type = types.int;
                                  description = "The number of uids in the range.";
                                };
                              };
                            }
                          );
                          default = [ ];
                          description = "Sub UID ranges for the user.";
                        };
                        subGidRanges = mkOption {
                          type = types.listOf (
                            types.submodule {
                              options = {
                                startGid = mkOption {
                                  type = types.int;
                                  description = "The starting gid for the range.";
                                };
                                count = mkOption {
                                  type = types.int;
                                  description = "The number of gids in the range.";
                                };
                              };
                            }
                          );
                          default = [ ];
                          description = "Sub GID ranges for the user.";
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
                              deterministicUid = cfg.${name}.uid or null;
                            in
                            mkIf (deterministicUid != null) (mkDefault deterministicUid);
                          subUidRanges =
                            let
                              deterministicSubUidRanges = cfg.${name}.subUidRanges or [ ];
                            in
                            mkIf (deterministicSubUidRanges != [ ]) (mkDefault deterministicSubUidRanges);
                          subGidRanges =
                            let
                              deterministicSubGidRanges = cfg.${name}.subGidRanges or [ ];
                            in
                            mkIf (deterministicSubGidRanges != [ ]) (mkDefault deterministicSubGidRanges);
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
                            deterministicGid = cfg.${name}.gid or null;
                          in
                          mkIf (deterministicGid != null) (mkDefault deterministicGid);
                      }
                    )
                  );
                };
              };
            };

            config = {
              assertions =
                concatLists (
                  flip mapAttrsToList config.users.users (
                    name: user: [
                      {
                        assertion = user.uid != null;
                        message = "non-deterministic uid detected for '${name}', please assign one via `users.deterministicIds`";
                      }
                      {
                        assertion = !user.autoSubUidGidRange;
                        message = "non-deterministic subUids/subGids detected for: ${name}";
                      }
                    ]
                  )
                )
                ++ flip mapAttrsToList config.users.groups (
                  name: group: {
                    assertion = group.gid != null;
                    message = "non-deterministic gid detected for '${name}', please assign one via `users.deterministicIds`";
                  }
                );
            };
          };
      };

      ids = den.lib.perHost {
        nixos =
          let
            uidGid = id: {
              uid = id;
              gid = id;
            };
          in
          {
            users.deterministicIds = {
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

              # System access groups (posix-enabled for Kanidm PAM/NSS)
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
          };
      };
    };
  };
}
