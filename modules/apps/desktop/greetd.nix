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
                "${pkgs.tuigreet}/bin/tuigreet"
                "--cmd '${lib.getExe config.programs.uwsm.package} start Hyprland'"
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

      # unlock keyring on login
      security.pam.services.greetd.enableGnomeKeyring = true;

      systemd.services.greetd.serviceConfig = {
        Type = "idle";
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "journal"; # Without this errors will spam on screen
        # Without these bootlogs will spam on screen
        TTYReset = true;
        TTYVHangup = true;
        TTYVTDisallocate = true;
      };

    };
}
