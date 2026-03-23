{
  features.wireless-initrd = {
    requires = [
      "network-boot"
      "wireless"
    ];
    linux =
      {
        config,
        lib,
        host,
        pkgs,
        ...
      }:
      let
        # Automatically detect wireless interface from facter hardware report
        # Wireless interfaces typically have names starting with "wl" (wlan, wlp, wlo, etc.)
        wirelessInterface = lib.findFirst (
          iface:
          iface ? unix_device_name && lib.hasPrefix "wl" iface.unix_device_name && iface ? driver_modules # Has driver modules
        ) null config.facter.report.hardware.network_interface;

        hasWireless = wirelessInterface != null;
        interface = if hasWireless then wirelessInterface.unix_device_name else "";

        initrdBootstrapKeys = host.hasFeature "initrd-bootstrap-keys";
      in
      lib.mkIf hasWireless {

        # NOTE: this does expose configured wireless passwords into the unencrypted
        # initrd, but if you have access to the unbooted machine you probably have
        # my wifi password...
        age.secrets.wpa-supplicant-initrd = {
          generator = {
            dependencies = [ config.age.secrets.wpa-supplicant ];
            script = "wpa-supplicant-config";
          };

          owner = "wpa_supplicant";
          settings.networks = config.networking.wireless.networks;
          rekeyFile = host.secretPath + "/wpa_supplicant_initrd.age";
        };

        boot = lib.mkIf (!initrdBootstrapKeys) {
          initrd = {
            # Wireless interface drivers are included by network-boot module
            availableKernelModules = [
              "ccm" # Cryptography libs for WPA
              "ctr"
              "iwlmvm" # Intel wireless controllers
              "iwlwifi"
            ];

            compressor = "zstd";
            compressorArgs = [ "-12" ];

            # extraFirmwarePaths = [ "iwlwifi-ma-b0-gf-a0-89.ucode.zst" ];
            extraFirmwarePaths = [ "iwlwifi-so-a0-gf-a0-89.ucode.zst" ];

            systemd = {
              # users.root.shell = "/bin/systemd-tty-ask-password-agent";
              emergencyAccess = true;

              # Wireless unlock support
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
                sshd = {
                  after = lib.mkForce [ "network.target" ];
                  wants = lib.mkForce [ ];
                  requires = lib.mkForce [ ];
                };

                zfs-import-zroot.after = [ "wpa_supplicant@${interface}.service" ];
                resolved.enable = true;
              };

              network = {
                enable = true;
                networks."10-wlan" = {
                  matchConfig.Name = interface;
                  networkConfig.DHCP = "yes";
                  # address = [ "10.9.100.100/16" ];
                  # gateway = [ "10.9.1.1" ];
                  # dns = [ "1.1.1.1" ];
                };
              };

            };

            network.enable = true;

            secrets."/etc/wpa_supplicant/wpa_supplicant-${interface}.conf" =
              config.age.secrets.wpa-supplicant-initrd.path;
          };
        };

        # Make sure that there is always a valid wpa_supplicant config available that can be
        # installed into the initrd. When bootstrapping a system (or re-installing), agenix
        # cannot succeed in decrypting whatever is given, since the correct hostkey doesn't
        # even exist yet. We still require a valid config to be available so that the initrd
        # can be generated successfully. The correct config will be installed with the next
        # update after the host is booted for the first time, and the secrets were rekeyed.
        system.activationScripts.agenixEnsureInitrdWpaSupplicantConfig = {
          text = ''
            if [[ ! -e ${config.age.secrets.wpa-supplicant-initrd.path} ]]; then
              # Create a minimal valid wpa_supplicant.conf as placeholder
              cat > ${config.age.secrets.wpa-supplicant-initrd.path} <<'EOF'
            # Placeholder wpa_supplicant config for initial deployment
            # This will be replaced with the real config after agenix rekey
            ctrl_interface=/var/run/wpa_supplicant
            update_config=1
            EOF
              chmod 600 ${config.age.secrets.wpa-supplicant-initrd.path}
            fi
          '';
          deps = [
            "agenixInstall"
          ];
        };

        system.activationScripts.agenixChown.deps = [ "agenixEnsureInitrdWpaSupplicantConfig" ];
      };
  };
}
