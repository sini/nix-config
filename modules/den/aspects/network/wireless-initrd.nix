# Wireless initrd: WiFi support in initrd for remote unlock over wireless.
# Auto-detects wireless interface from facter hardware report.
{ den, lib, ... }:
{
  den.aspects.wireless-initrd = {
    includes = [
      den.aspects.initrd-bootstrap-keys
      den.aspects.network-boot
    ]
    ++ lib.attrValues den.aspects.wireless-initrd._;

    _ = {
      config = den.lib.perHost {
        nixos =
          {
            config,
            secrets,
            lib,
            pkgs,
            ...
          }:
          let
            # Automatically detect wireless interface from facter hardware report
            wirelessInterface = lib.findFirst (
              iface:
              iface ? unix_device_name && lib.hasPrefix "wl" iface.unix_device_name && iface ? driver_modules
            ) null (config.facter.report.hardware.network_interface or [ ]);

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

                secrets."/etc/wpa_supplicant/wpa_supplicant-${interface}.conf" = secrets.wpa-supplicant-initrd;
              };
            };
          };
      };
    };
  };
}
