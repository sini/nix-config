_:
{
  den.aspects.desktop.gdm = {
    nixos =
      { pkgs, ... }:
      {
        services.displayManager.gdm = {
          enable = true;
          autoSuspend = false;
          wayland = true;
        };

        security.pam.services = {
          gdm-autologin-keyring.text = ''
            auth      optional      ${pkgs.gdm}/lib/security/pam_gdm.so
            auth      optional      ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so
          '';
        };
      };
  };
}
