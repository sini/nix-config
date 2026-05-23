_:
{
  den.aspects.core.plymouth = {
    nixos = {
      boot = {
        plymouth.enable = true;
        consoleLogLevel = 3;
        initrd.verbose = false;
        kernelParams = [
          "quiet"
          "splash"
          "intremap=on"
          "boot.shell_on_fail"
          "udev.log_priority=3"
          "rd.systemd.show_status=auto"
        ];
      };
    };

    persist = {
      directories = [ "/var/lib/plymouth" ];
    };
  };
}
