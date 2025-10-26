{ config, ... }:
{
  flake.features.razer = {
    nixos =
      { pkgs, ... }:
      {
        hardware.openrazer.enable = true;
        environment.systemPackages = with pkgs; [
          openrazer-daemon
          polychromatic
        ];
        hardware.openrazer.users = [ config.flake.meta.user.username ];
        persistence."/persist".directories = [
          ".config/openrazer/"
          ".config/polychromatic/"
        ];
      };
    home = {
      home.persistence."/persist".directories = [
        ".config/openrazer/"
        ".config/polychromatic/"
      ];

    };
  };
}
