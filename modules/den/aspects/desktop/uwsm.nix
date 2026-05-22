{ den, ... }:
{
  den.aspects.desktop.uwsm = {
    nixos =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        programs.uwsm.enable = true;

        environment = {
          systemPackages = [ pkgs.app2unit ];
          sessionVariables = {
            NIXOS_OZONE_WL = "1";
            GSK_RENDERER = "cairo";
            APP2UNIT_SLICES = "a=app-graphical.slice b=background-graphical.slice s=session-graphical.slice";
            APP2UNIT_TYPE = "scope";
          };
        };

        systemd.user.services.fumon = {
          enable = true;
          wantedBy = [ "graphical-session.target" ];
          path = lib.mkForce [ ];
          serviceConfig.ExecStart = [
            ""
            (lib.getExe' config.programs.uwsm.package "fumon")
          ];
        };
      };
  };
}
