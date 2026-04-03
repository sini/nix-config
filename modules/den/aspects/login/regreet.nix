{ den, ... }:
{
  den.aspects.regreet = den.lib.perHost {
    nixos = {
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
        StandardError = "journal";
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
  };
}
