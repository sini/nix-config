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

        systemd.user.services.razerdaemon = {
          unitConfig.ConditionUser = "!media";
        };

        systemd.user.services.razer-activate-power-unlock = {
          description = "Uncap power limits";
          after = [ "razerdaemon.service" ];
          requires = [ "razerdaemon.service" ];
          unitConfig.ConditionUser = "!media";
          path = with pkgs; [
            razer-cli
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "razer-uncap-ac-power" ''
              set -e
              razer-cli write power ac 4 3 2
            '';
          };
          wantedBy = [ "default.target" ];
        };
      };

    home = {
      home.persistence."/persist".directories = [
        ".config/openrazer/"
        ".config/polychromatic/"
        ".local/share/razercontrol"
      ];

    };
  };
}
