{
  flake.modules.nixos.greetd =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services = {
        greetd = {
          enable = true;
          settings = {
            default_session = {
              command = lib.concatStringsSep " " [
                "${pkgs.greetd.tuigreet}/bin/tuigreet"
                "--cmd '${lib.getExe config.programs.uwsm.package} start hyprland'"
                "--asterisks"
                "--remember"
                "--remember-user-session"
                ''
                  --greeting "Hey you. You're finally awake."

                ''
              ];
              user = "greeter";
            };
          };
        };
      };
    };
}
