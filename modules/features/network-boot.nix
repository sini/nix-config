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
              # Generate proper wpa_supplicant config for initrd, replicating NixOS logic
              # This avoids IFD by using the same generation logic as the main wpa_supplicant module

              # Replicate the mkNetwork function from wpa_supplicant.nix
              mkNetwork =
                opts:
                let
                  quote = x: ''"${x}"'';
                  indent = x: "  " + x;
                  pskString = if opts.psk or null != null then quote opts.psk else opts.pskRaw or null;
                  options = [
                    "ssid=${quote opts.ssid}"
                    (
                      if pskString != null || opts.auth or null != null then
                        "key_mgmt=${lib.concatStringsSep " " (opts.authProtocols or [ "WPA-PSK" ])}"
                      else
                        "key_mgmt=NONE"
                    )
                  ]
                  ++ lib.optional (opts.hidden or false) "scan_ssid=1"
                  ++ lib.optional (pskString != null) "psk=${pskString}"
                  ++ lib.optional (opts.priority or null != null) "priority=${toString opts.priority}";
                in
                ''
                  network={
                  ${lib.concatMapStringsSep "\n" indent options}
                  }
                '';

              # Generate networks list
              networkList = lib.mapAttrsToList (
                ssid: opts: opts // { inherit ssid; }
              ) config.networking.wireless.networks;

              # Generate the full config content
              generatedConfig = lib.concatStringsSep "\n" (
                (map mkNetwork networkList)
                ++ [
                  "ctrl_interface=/run/wpa_supplicant"
                  "update_config=1"
                  "pmf=1"
                ]
                ++ lib.optional (
                  config.networking.wireless.secretsFile != null
                ) "ext_password_backend=file:${config.networking.wireless.secretsFile}"
                ++ lib.optional config.networking.wireless.scanOnLowSignal ''bgscan="simple:30:-70:3600"''
                ++ lib.optional (
                  config.networking.wireless.extraConfig != ""
                ) config.networking.wireless.extraConfig
              );

              initrdWpaConfig = pkgs.writeText "initrd-wpa_supplicant.conf" generatedConfig;
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

              # Dependencies aren't tracked properly:
              # https://github.com/NixOS/nixpkgs/issues/309316
              storePaths =
                config.boot.initrd.systemd.services.wpa_supplicant.path
                ++ config.systemd.services.wpa_supplicant.path
                ++ [
                  pkgs.wpa_supplicant
                  initrdWpaConfig
                ];

              services.wpa_supplicant = {
                wantedBy = [ "initrd.target" ];
                path = config.systemd.services.wpa_supplicant.path;

                # Use the original script approach: extract the config file path and replace it
                # This preserves interface detection and other logic from the original service
                script =
                  let
                    # Extract the config file path that would be used by the regular systemd service
                    # This works without IFD since we're doing string replacement, not file reading
                    originalScript = config.systemd.services.wpa_supplicant.script;
                    # Find any wpa_supplicant.conf file references and replace with our initrd config
                    scriptWithNewConfig =
                      builtins.replaceStrings [ "wpa_supplicant.conf" ] [ "${initrdWpaConfig}" ]
                        originalScript;
                  in
                  # Remove startup args that aren't appropriate for initrd
                  builtins.replaceStrings [ "-s -u " ] [ "" ] scriptWithNewConfig;
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
