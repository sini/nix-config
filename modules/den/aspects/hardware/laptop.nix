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

        boot.kernelParams = [
          "pcie_aspm=force"
          "pcie_aspm.policy=powersupersave"
        ];

        powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

        services = {
          udev.extraRules = ''
            # Dynamic Energy Performance Preference (EPP) for Intel Speed Shift / AMD P-State HWP
            ACTION=="add|change", SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.writeShellScript "battery-epp" ''
              for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                echo balance_power > "$f" 2>/dev/null || true
              done
            ''}"
            ACTION=="add|change", SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.writeShellScript "ac-epp" ''
              for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                echo balance_performance > "$f" 2>/dev/null || true
              done
            ''}"
          '';

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

          thermald.enable = true;
        };
      };
  };
}
