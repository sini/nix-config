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
              # Use the main wpa_supplicant service logic in initrd
              services.wpa_supplicant = {
                wantedBy = [ "initrd.target" ];
                path = config.systemd.services.wpa_supplicant.path;
                script = ''
                  if [ -f /etc/wpa_supplicant.conf ]; then
                    echo >&2 "<3>/etc/wpa_supplicant.conf present but ignored. Generated ${initrdWpaConfig} is used instead."
                  fi

                  # ensure wpa_supplicant.conf exists, or the daemon will fail to start

                  iface_args="-s -u -Dnl80211,wext -c ${initrdWpaConfig}"

                  # detect interfaces automatically

                  # check if there are no wireless interfaces
                  if ! find -H /sys/class/net/* -name wireless | grep -q .; then
                    # if so, wait until one appears
                    echo "Waiting for wireless interfaces"
                    grep -q '^ACTION=add' < <(stdbuf -oL -- udevadm monitor -s net/wlan -pu)
                    # Note: the above line has been carefully written:
                    # 1. The process substitution avoids udevadm hanging (after grep has quit)
                    #    until it tries to write to the pipe again. Not even pipefail works here.
                    # 2. stdbuf is needed because udevadm output is buffered by default and grep
                    #    may hang until more udev events enter the pipe.
                  fi

                  # add any interface found to the daemon arguments
                  for name in $(find -H /sys/class/net/* -name wireless | cut -d/ -f 5); do
                    echo "Adding interface $name"
                    args+="''${args:+ -N} -i$name $iface_args"
                  done

                  # finally start daemon
                  exec wpa_supplicant $args
                '';
              };

              # Ensure wpa_supplicant and dependencies are available in initrd
              packages = [ pkgs.wpa_supplicant ];
              initrdBin = [
                pkgs.wpa_supplicant
                pkgs.coreutils
                pkgs.systemd
                pkgs.iproute2
              ];

              # Dependencies aren't tracked properly:
              # https://github.com/NixOS/nixpkgs/issues/309316
              storePaths = [
                pkgs.wpa_supplicant
                pkgs.coreutils
                pkgs.findutils
                pkgs.gnugrep
                pkgs.gnused
                pkgs.systemd
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
