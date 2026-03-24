{
  features.wireless-initrd = {
    requires = [
      "initrd-bootstrap-keys"
      "network-boot"
      "wireless"
    ];
    linux =
      {
        config,
        lib,
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
      in
      lib.mkIf hasWireless {
        boot = {
          initrd = {
            # Wireless interface drivers are included by network-boot module
            availableKernelModules = [
              "ccm" # Cryptography libs for WPA
              "ctr"
              "cmac" # Needed for WPA3
            ];

            compressor = "zstd";
            compressorArgs = [ "-12" ];

            # extraFirmwarePaths = [ "iwlwifi-ma-b0-gf-a0-89.ucode.zst" ];
            extraFirmwarePaths = [ "iwlwifi-so-a0-gf-a0-89.ucode.zst" ];

            systemd = {
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

                systemd-networkd.after = [ "wpa_supplicant@${interface}.service" ];

                sshd = {
                  after = lib.mkForce [ "network.target" ];
                  wants = lib.mkForce [ ];
                  requires = lib.mkForce [ ];
                };

                resolved.enable = true;
              };

            };

            secrets."/etc/wpa_supplicant/wpa_supplicant-${interface}.conf" =
              config.age.secrets.wpa-supplicant-initrd.path;
          };
        };
      };
  };
}
