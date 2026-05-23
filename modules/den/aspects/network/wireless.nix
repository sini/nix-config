{
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.network.wireless = {
    nixos =
      {
        config,
        host,
        ...
      }:
      let
        env = environments.${host.environment};

        wirelessInterface = lib.findFirst (
          iface:
          iface ? unix_device_name && lib.hasPrefix "wl" iface.unix_device_name && iface ? driver_modules
        ) null config.facter.report.hardware.network_interface;

        hasWireless = wirelessInterface != null;
        interface = if hasWireless then wirelessInterface.unix_device_name else "";
      in
      lib.mkIf hasWireless {
        age.secrets.wpa-supplicant = {
          rekeyFile = env.wirelessSecretsFile;
          owner = "wpa_supplicant";
        };

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

            networks = lib.mkIf (env.networks.default.wireless or null != null) {
              "${env.networks.default.wireless.ssid}".pskRaw = env.networks.default.wireless.pskRef;
            };
          };
        };
      };

    persist = {
      directories = [
        "/etc/wpa_supplicant"
        "/var/lib/iwd"
      ];
    };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.impala
        ];
      };
  };
}
