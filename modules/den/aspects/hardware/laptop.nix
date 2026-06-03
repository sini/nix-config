{
  den.aspects.hardware.laptop = {

    # Laptops use NetworkManager for userspace WiFi (roaming, multiple
    # networks). Standalone wpa_supplicant (network.wireless) is opt-in
    # per-host and conflicts with NM over the interface if both manage it.

    persist = {
      directories = [
        "/var/lib/upower"
        "/var/lib/power-profiles-daemon"
      ];
    };

    nixos =
      { pkgs, lib, ... }:
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
