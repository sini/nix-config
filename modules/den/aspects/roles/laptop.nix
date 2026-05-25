{ den, lib, ... }:
{
  den.aspects.roles.laptop = {
    colmena = [ "laptop" ];
    includes = with den.aspects; [
      network.wireless
    ];

    persist = {
      directories = [
        "/var/lib/upower"
        "/var/lib/power-profiles-daemon"
      ];
    };

    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.brightnessctl
        ];

        networking.networkmanager.wifi = {
          powersave = true;
          macAddress = "preserve";
        };

        powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

        services = {
          logind.settings.Login = {
            HandleLidSwitch = "suspend";
            HandleLidSwitchExternalPower = "ignore";
            HandleLidSwitchDocked = "ignore";
            HandlePowerKey = "suspend";
            HandleSuspendKey = "suspend";
            HandleHibernateKey = "suspend";
            PowerKeyIgnoreInhibited = "yes";
            SuspendKeyIgnoreInhibited = "yes";
            HibernateKeyIgnoreInhibited = "yes";
          };

          power-profiles-daemon.enable = false;

          scx = {
            enable = true;
            package = lib.mkForce pkgs.scx.full;
            scheduler = lib.mkForce "scx_lavd";
            extraArgs = [
              "--autopower"
            ];
          };

          auto-cpufreq = {
            enable = true;
            settings = {
              battery = {
                energy_performance_preference = lib.mkDefault "balance_power";
                turbo = "never";
              };
              charger = {
                energy_performance_preference = lib.mkDefault "balance_performance";
                turbo = "auto";
              };
            };
          };

          thermald.enable = true;
        };
      };
  };
}
