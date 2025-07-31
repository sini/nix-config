{
  flake.modules.nixos.laptop =
    { lib, ... }:
    {
      services = {
        # tlp.enable = true;
        logind = {
          lidSwitch = "ignore";
          lidSwitchDocked = "ignore";
          lidSwitchExternalPower = "ignore";
          extraConfig = ''
            HandlePowerKey=suspend
            HandleSuspendKey=suspend
            HandleHibernateKey=suspend
            PowerKeyIgnoreInhibited=yes
            SuspendKeyIgnoreInhibited=yes
            HibernateKeyIgnoreInhibited=yes
          '';
        };
      };
      powerManagement.cpuFreqGovernor = lib.mkDefault "shedutil";

      services.power-profiles-daemon.enable = false; # Disable GNOMEs power management

      # Enable TLP for power management, should be okay for all systems
      services.tlp = {
        enable = true;
        settings = {
          CPU_BOOST_ON_AC = 1;
          CPU_BOOST_ON_BAT = 1;
          CPU_HWP_DYN_BOOST_ON_AC = 1;
          CPU_HWP_DYN_BOOST_ON_BAT = 1;

          CPU_SCALING_GOVERNOR_ON_AC = "performance";
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

          CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
          CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

          PLATFORM_PROFILE_ON_AC = "performance";
          PLATFORM_PROFILE_ON_BAT = "balanced";

          CPU_MIN_PERF_ON_AC = 0;
          CPU_MAX_PERF_ON_AC = 100;
          CPU_MIN_PERF_ON_BAT = 0;
          CPU_MAX_PERF_ON_BAT = 20;

          USB_AUTOSUSPEND = 0;
        };
      };
      # services.auto-cpufreq = {
      #   enable = true;
      #   settings = {

      #     battery = {
      #       governor = "powersave";
      #       energy_performance_preference = lib.mkDefault "power";
      #       turbo = "never";
      #     };

      #     charger = {
      #       governor = "performance";
      #       energy_performance_preference = lib.mkDefault "performance";
      #       turbo = "auto";
      #     };

      #   };
      # };
    };
}
