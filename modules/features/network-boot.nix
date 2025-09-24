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
              targets.initrd.wants = [ "wpa_supplicant.service" ];
              # Simple wpa_supplicant service for initrd
              services.wpa_supplicant = {
                unitConfig.DefaultDependencies = false;
                path = config.systemd.services.wpa_supplicant.path;
                script = ''
                  # Find wireless interfaces and start wpa_supplicant
                  for name in $(find -H /sys/class/net/* -name wireless 2>/dev/null | cut -d/ -f 5); do
                    echo "Starting wpa_supplicant on interface $name"
                    exec wpa_supplicant -s -u -Dnl80211,wext -i$name -c ${initrdWpaConfig}
                  done
                  echo "No wireless interfaces found"
                  exit 1
                '';
              };
              packages = [ pkgs.wpa_supplicant ];
              initrdBin = [
                pkgs.wpa_supplicant
                pkgs.coreutils
                pkgs.systemd
                pkgs.iproute2
              ];
              storePaths = config.boot.initrd.systemd.services.wpa_supplicant.path ++ [
                initrdWpaConfig
              ];
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
