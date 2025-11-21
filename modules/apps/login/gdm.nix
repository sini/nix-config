{
  flake.features.gdm.nixos =
    { pkgs, ... }:
    {
      services = {
        displayManager = {
          gdm = {
            enable = true;
            autoSuspend = false;
            wayland = true;
          };
        };
      };

      # PAM configuration for GNOME keyring auto-unlock
      security.pam.services = {
        gdm-autologin-keyring.text = ''
          auth      optional      ${pkgs.gdm}/lib/security/pam_gdm.so
          auth      optional      ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so
        '';
      };
    };
}
