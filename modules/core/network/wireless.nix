{
  features.wireless = {
    linux =
      {
        config,
        lib,
        environment,
        ...
      }:
      let
        # Automatically detect wireless interface from facter hardware report
        # Wireless interfaces typically have names starting with "wl" (wlan, wlp, wlo, etc.)
        wirelessInterface = lib.findFirst (
          iface:
          iface ? unix_device_name && lib.hasPrefix "wl" iface.unix_device_name && iface ? driver_modules
        ) null config.facter.report.hardware.network_interface;

        hasWireless = wirelessInterface != null;
        interface = if hasWireless then wirelessInterface.unix_device_name else "";
      in
      lib.mkIf hasWireless {
        # # This is just a wpa_supplicant.conf for booting, it's super simple -- one ESSID + psk
        # age.secrets.wpa-supplicant-config = {
        #   rekeyFile = rootPath + "/.secrets/user/wpa_supplicant-config.age";
        #   path = "/root/.wpa_supplicant/wpa_supplicant.conf";
        #   symlink = false;
        # };

        age.secrets.wpa-supplicant = {
          rekeyFile = environment.secretPath + "/wpa_supplicant-arcade.age";
          owner = "wpa_supplicant";
        };

        boot.extraModprobeConfig = ''
          options iwlwifi power_save=1
          options iwlwifi power_level=1
          options iwlmvm power_scheme=3
        ''; # TODO: if kernelModules contains these...

        systemd.network.networks."80-wireless" = {
          matchConfig.Name = interface;
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
            IPv6PrivacyExtensions = "yes";
          };
          linkConfig.RequiredForOnline = "routable";
        };

        networking = {
          networkmanager = {
            unmanaged = [ interface ];
            wifi.backend = "wpa_supplicant";
          };

          wireless = {
            enable = true;

            userControlled.enable = true;

            interfaces = [ interface ];

            secretsFile = config.age.secrets.wpa-supplicant.path;

            networks = {
              "The Arcade".pskRaw = "ext:psk_arcade";
            };

            # extraConfig = "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel";
          };
        };

        environment.persistence."/cache".directories = [
          "/etc/wpa_supplicant"
          "/var/lib/iwd"
        ];
      };

    home =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.impala
        ];
      };
  };
}
