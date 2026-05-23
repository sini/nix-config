{ inputs, ... }:
{
  den.aspects.hardware.razer = {
    nixos =
      { pkgs, ... }:
      {
        imports = [ inputs.razerdaemon.nixosModules.default ];

        services.razer-laptop-control.enable = true;

        hardware.openrazer.enable = true;
        environment.systemPackages = [
          pkgs.openrazer-daemon
          pkgs.polychromatic
        ];

        systemd.user.services.razerdaemon = {
          unitConfig.ConditionUser = "!media";
        };

        systemd.user.services.razer-activate-power-unlock = {
          description = "Uncap power limits";
          after = [ "razerdaemon.service" ];
          requires = [ "razerdaemon.service" ];
          unitConfig.ConditionUser = "!media";
          path = [ pkgs.razer-cli ];
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

    persistHome = {
      directories = [
        ".config/openrazer/"
        ".config/polychromatic/"
        ".local/share/razercontrol"
      ];
    };
  };
}
