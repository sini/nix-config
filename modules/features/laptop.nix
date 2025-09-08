{
  flake.modules.nixos.laptop =
    { pkgs, lib, ... }:
    {
      environment.systemPackages = with pkgs; [
        brightnessctl
      ];

      powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

      services = {
        power-profiles-daemon.enable = false; # Disable GNOMEs power management
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
