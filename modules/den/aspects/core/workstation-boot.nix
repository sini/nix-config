{ den, lib, ... }:
{
  den.aspects.workstation-boot = {
    includes = lib.attrValues den.aspects.workstation-boot._;

    _ = {
      config = den.lib.perHost {
        os = {
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
      };

      impermanence = den.lib.perHost {
        persist.directories = [ "/var/lib/plymouth" ];
      };
    };
  };
}
