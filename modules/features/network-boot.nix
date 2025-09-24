# initrd-wifi support based on https://github.com/dlo9/nixos-config/blob/main/hosts/wyse/initrd-wifi.nix
{
  flake.modules.nixos.network-boot =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      system.activationScripts.agenixChown.deps = [ "agenixEnsureInitrdWpaSupplicantConfig" ];

      boot = {
        initrd = {
          availableKernelModules = [
            "r8169" # Host: surge, burst, pulse
            "mlx4_core"
            "mlx4_en" # Hosts: uplink, cortex
            "bridge"
            "bonding"
            "8021q"
          ]
          ++ lib.optionals config.networking.wireless.enable [
            # Wireless unlocking support
            "ccm"
            "ctr"
            "iwlmvm"
            "iwlwifi"
            "cfg80211"
            "mwifiex"
            "mwifiex_pcie"
          ];

          systemd = {
            inherit (config.systemd) network;
            emergencyAccess = true;
          }
          // lib.optionalAttrs config.networking.wireless.enable (
            let
              # Get the config file
              # We can to use writeStringReferencesToFile instead of manually parsing or else nix complains
              # about accessing absolute paths during pure evaluation
              oldWirelessConfig = builtins.head (
                lib.splitString "\n" (
                  lib.readFile (pkgs.writeStringReferencesToFile config.systemd.services.wpa_supplicant.script)
                )
              );

              # Wheel doesn't exist in initrd
              newWirelessConfig = builtins.toFile "wpa_supplicant.conf" (
                builtins.replaceStrings [ "ctrl_interface_group=wheel" ] [ "" ] (
                  builtins.readFile oldWirelessConfig
                )
              );
            in
            {
              # Wireless unlock support
              packages = [ pkgs.wpa_supplicant ];
              initrdBin = [
                pkgs.wpa_supplicant
                pkgs.coreutils
                pkgs.systemd
                pkgs.iproute2
              ];

              storePaths =
                config.boot.initrd.systemd.services.wpa_supplicant.path
                ++ (lib.splitString "\n" (
                  lib.readFile (
                    pkgs.writeStringReferencesToFile config.boot.initrd.systemd.services.wpa_supplicant.script
                  )
                ));

              services.wpa_supplicant = {
                wantedBy = [ "initrd.target" ];
                path = config.systemd.services.wpa_supplicant.path;

                # Replace the old config with our new one
                # Remove some startup args
                script =
                  builtins.replaceStrings [ oldWirelessConfig "-s -u " ] [ newWirelessConfig "" ]
                    config.systemd.services.wpa_supplicant.script;
              };
            }
          );

          network = {
            enable = true;
            ssh = {
              enable = true;
              port = 22;
              authorizedKeys =
                with lib;
                concatLists (
                  mapAttrsToList (
                    _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
                  ) config.users.users
                );
              hostKeys = [
                config.age.secrets.initrd_host_ed25519_key.path
              ];

              # Automatically prompt for password...
              extraConfig = "ForceCommand systemd-tty-ask-password-agent --watch";
            };
          };
        }
        // lib.optionalAttrs config.networking.wireless.enable {
          secrets."${config.age.secrets.wpa-supplicant.path}" = config.age.secrets.wpa-supplicant.path;
        };
      };
    };
}
