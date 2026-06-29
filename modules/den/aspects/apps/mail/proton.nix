# Proton Mail Bridge. The nixpkgs bridge + its systemd user service are Linux
# only; macOS gets the bridge via the `proton-mail-bridge` cask.
{
  den.aspects.apps.mail.protonmail = {
    homebrew-cask = [ "proton-mail-bridge" ];

    homeLinux =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.protonmail-bridge ];

        services.protonmail-bridge = {
          enable = true;
          extraPackages = with pkgs; [
            gnome-keyring
            libnotify
            gnupg
          ];
        };
      };
  };
}
