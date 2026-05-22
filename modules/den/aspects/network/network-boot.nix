{ den, lib, ... }:
{
  den.aspects.network.network-boot = {
    nixos =
      { config, pkgs, host, ... }:
      let
        jweToken = builtins.path {
          path = host.secretPath + "/zroot-key.jwe";
          name = "zroot-key.jwe";
        };

        # Collect network driver modules from facter hardware report
        baseNetworkDriverModules = lib.unique (
          lib.flatten (
            lib.filter (x: x != null) (
              map (iface: iface.driver_modules or null) config.facter.report.hardware.network_interface
            )
          )
        );

        moduleDependencies = {
          "mlx4_core" = [ "mlx4_en" ];
          "iwlwifi" = [ "iwlmvm" ];
        };

        additionalDriverModules = lib.unique (
          lib.flatten (map (mod: moduleDependencies.${mod} or [ ]) baseNetworkDriverModules)
        );

        networkDriverModules = lib.unique (baseNetworkDriverModules ++ additionalDriverModules);

        # Wireless initrd support
        wirelessInterface = lib.findFirst (
          iface:
          iface ? unix_device_name && lib.hasPrefix "wl" iface.unix_device_name && iface ? driver_modules
        ) null config.facter.report.hardware.network_interface;

        hasWireless = wirelessInterface != null;
        interface = if hasWireless then wirelessInterface.unix_device_name else "";
      in
      {
        boot.initrd = {
          availableKernelModules = [
            "bridge"
            "bonding"
            "8021q"
            "tpm_crb"
            "tpm_tis"
          ] ++ networkDriverModules
          ++ lib.optionals hasWireless [
            "ccm"
            "ctr"
            "cmac"
          ];

          clevis = {
            enable = true;
            useTang = true;
            devices.zroot.secretFile = jweToken;
          };

          systemd = {
            inherit (config.systemd) network;

            services.zfs-import-zroot.preStart = ''
              /bin/sleep 10
              ${lib.getExe config.boot.zfs.package} load-key -a
            '';
          } // lib.optionalAttrs hasWireless {
            packages = [ pkgs.wpa_supplicant ];
            initrdBin = [
              pkgs.wpa_supplicant
              pkgs.coreutils
              pkgs.systemd
              pkgs.iproute2
            ];

            targets.initrd.wants = [
              "wpa_supplicant@${interface}.service"
              "systemd-resolved.service"
            ];
            services = {
              "wpa_supplicant@" = {
                unitConfig.DefaultDependencies = false;
                after = lib.mkForce [ "sys-subsystem-net-devices-%i.device" ];
                requires = lib.mkForce [ "sys-subsystem-net-devices-%i.device" ];
              };

              systemd-networkd.after = [ "wpa_supplicant@${interface}.service" ];

              sshd = {
                after = lib.mkForce [ "network.target" ];
                wants = lib.mkForce [ ];
                requires = lib.mkForce [ ];
              };

              resolved.enable = true;
            };
          };

          network = {
            enable = true;
            ssh = {
              enable = false; # TODO: enable once user SSH keys + initrd host key are wired
              port = 22;
            };
          };
        } // lib.optionalAttrs hasWireless {
          compressor = "zstd";
          compressorArgs = [ "-12" ];
          extraFirmwarePaths = [ "iwlwifi-so-a0-gf-a0-89.ucode.zst" ];
        };
      };

    age-secrets =
      { host, ... }:
      {
        age.secrets = {
          initrd_host_ed25519_key.generator.script = "ssh-key";

          wpa-supplicant-keys-for-initrd = {
            intermediary = true;
            # TODO: wire environment.wirelessSecretsFile once environment ref lands
          };

          wpa-supplicant-initrd = {
            generator = {
              script = "wpa-supplicant-config";
            };
          };
        };
      };
  };
}
