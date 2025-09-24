{
  flake.modules.nixos.laptop =
    { pkgs, lib, ... }:
    {
      environment.systemPackages = with pkgs; [
        brightnessctl
      ];

      powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

      services = {
        # Configure sane locking behavior -- if it's on power we don't sleep unless told to
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

        power-profiles-daemon.enable = false; # Disable GNOMEs power management

        # https://wiki.cachyos.org/configuration/sched-ext/
        # https://github.com/sched-ext/scx/tree/main/scheds/rust/scx_lavd
        scx = {
          enable = true;
          package = lib.mkDefault pkgs.scx.full;
          scheduler = "scx_lavd"; # Default is scx_rustland
          # Enable: Autoimatic Power
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

        # Only required on intel... our only x86 laptop is intel sooo...
        thermald.enable = true;
      };
    };
}
