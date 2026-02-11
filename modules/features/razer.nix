{ config, ... }:
{
  flake.features.razer = {
    nixos =
      { inputs, pkgs, ... }:
      {
        imports = [ inputs.razerdaemon.nixosModules.default ];

        services.razer-laptop-control.enable = true;

        hardware.openrazer.enable = true;
        environment.systemPackages = with pkgs; [
          openrazer-daemon
          polychromatic
        ];
        hardware.openrazer.users = [ config.flake.meta.user.username ];
      };

    home = {
      home.persistence."/persist".directories = [
        ".config/openrazer/"
        ".config/polychromatic/"
      ];

    };
  };
}
