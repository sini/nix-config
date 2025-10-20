{ rootPath, ... }:
{
  flake.features.wireless.nixos =
    {
      config,
      environment,
      ...
    }:
    {
      # # This is just a wpa_supplicant.conf for booting, it's super simple -- one ESSID + psk
      # age.secrets.wpa-supplicant-config = {
      #   rekeyFile = rootPath + "/.secrets/user/wpa_supplicant-config.age";
      #   path = "/root/.wpa_supplicant/wpa_supplicant.conf";
      #   symlink = false;
      # };

      age.secrets.wpa-supplicant = {
        rekeyFile = rootPath + "/.secrets/env/${environment.name}/wpa_supplicant-arcade.age";
      };

      environment.persistence."/volatile".directories = [
        "/etc/wpa_supplicant"
        "/var/lib/iwd"
      ];

      # Ensure a file exists so that we can write the initrd, even if it's not valid
      system.activationScripts.agenixEnsureInitrdWpaSupplicantConfig = {
        text = ''
          [[ -e ${config.age.secrets.wpa-supplicant.path} ]] \
            || touch ${config.age.secrets.wpa-supplicant.path}
        '';
        deps = [
          "agenixInstall"
          "users"
        ];
      };

      system.activationScripts.agenixChown.deps = [ "agenixEnsureInitrdWpaSupplicantConfig" ];

      networking.wireless = {
        enable = true;
        secretsFile = config.age.secrets.wpa-supplicant.path;
        networks = {
          "The Arcade".pskRaw = "ext:psk_arcade";
        };
      };
    };
}
