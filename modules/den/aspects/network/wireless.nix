{ den, lib, ... }:
{
  den.aspects.wireless = {
    includes = lib.attrValues den.aspects.wireless._;

    _ = {
      config = den.lib.perHost (
        { host }:
        {
          nixos =
            { config, lib, ... }:
            let
              wirelessInterface = lib.findFirst (
                iface:
                iface ? unix_device_name && lib.hasPrefix "wl" iface.unix_device_name && iface ? driver_modules
              ) null config.facter.report.hardware.network_interface;

              hasWireless = wirelessInterface != null;
              interface = if hasWireless then wirelessInterface.unix_device_name else "";
            in
            lib.mkIf hasWireless {
              boot.extraModprobeConfig = ''
                options iwlwifi power_save=1
                options iwlwifi power_level=1
                options iwlmvm power_scheme=3
              '';

              networking = {
                networkmanager.wifi.backend = "wpa_supplicant";

                wireless = {
                  enable = true;
                  userControlled = true;
                  interfaces = [ interface ];
                  secretsFile = config.age.secrets.wpa-supplicant.path;
                  networks = lib.mkIf (host.environment.networks.default.wireless != null) {
                    "${host.environment.networks.default.wireless.ssid}".pskRaw =
                      host.environment.networks.default.wireless.pskRef;
                  };
                };
              };
            };
        }
      );

      secrets = den.lib.perHost (
        { host }:
        {
          nixos =
            { config, lib, ... }:
            let
              wirelessInterface = lib.findFirst (
                iface:
                iface ? unix_device_name && lib.hasPrefix "wl" iface.unix_device_name && iface ? driver_modules
              ) null config.facter.report.hardware.network_interface;
              hasWireless = wirelessInterface != null;
            in
            lib.mkIf hasWireless {
              age.secrets.wpa-supplicant = {
                rekeyFile = host.environment.wirelessSecretsFile;
                owner = "wpa_supplicant";
              };
            };
        }
      );

      impermanence = den.lib.perHost {
        nixos =
          { config, lib, ... }:
          let
            wirelessInterface = lib.findFirst (
              iface:
              iface ? unix_device_name && lib.hasPrefix "wl" iface.unix_device_name && iface ? driver_modules
            ) null config.facter.report.hardware.network_interface;
            hasWireless = wirelessInterface != null;
          in
          lib.mkIf hasWireless {
            environment.persistence."/cache".directories = [
              "/etc/wpa_supplicant"
              "/var/lib/iwd"
            ];
          };
      };

      home = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = [
              pkgs.impala
            ];
          };
      };
    };
  };
}
