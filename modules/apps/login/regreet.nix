{
  flake.aspects.regreet.nixos = {
    services.greetd.enable = true;

    users.extraUsers.greeter = {
      home = "/tmp/greeter-home";
      createHome = true;
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

    programs.regreet = {
      enable = true;
      cageArgs = [
        "-s"
        "-m"
        "last"
      ];
      settings = {
        appearance = {
          greeting_msg = "Hello Word!";
        };
        commands = {
          reboot = [
            "systemctl"
            "reboot"
          ];
          poweroff = [
            "systemctl"
            "poweroff"
          ];
        };
        widget.clock = {
          format = "%a %T";
          label_width = 150;
        };
      };
    };

  };
}
