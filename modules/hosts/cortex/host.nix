{ config, ... }:
{
  flake.hosts.cortex = {
    ipv4 = "10.10.10.9";
    environment = "dev";
    roles = [
      "workstation"
      "gaming"
    ];
    extra_modules = with config.flake.modules.nixos; [
      cpu-amd
      gpu-amd
      gpu-nvidia
      disk-single
      performance
    ];
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDFFLWZzC91VBRxi3KwvRm7pI2vaAItIf9Nnd3Eifkmc";
    facts = ./facter.json;
  };

  flake.modules.nixos.host_cortex =
    {
      pkgs,
      ...
    }:
    {
      hardware.disk.single.device_id = "nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X704630A";
      hardware.networking.interfaces = [ "enp6s0" ];

      boot.kernelPackages = pkgs.linuxPackages_cachyos-gcc; # TODO: https://github.com/chaotic-cx/nyx/issues/1178
      # use TCP BBR has significantly increased throughput and reduced latency for connections
      boot.kernelModules = [
        "ntsync"
        "it87" # Fan options
      ];
      # Enable fan sensors...
      boot.kernelParams = [ "acpi_enforce_resources=lax" ];
      boot.extraModprobeConfig = ''
        options it87 ignore_resource_conflict=1 force_id=0x8628
      '';
      boot.kernel.sysctl = {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };

      environment.systemPackages = with pkgs; [
        lm_sensors
      ];

      home-manager.users.${config.flake.meta.user.username}.imports = [
        {
          wayland.windowManager.hyprland.settings.monitor = [
            "DP-3, 2560x2880@59.98, 0x0, 1, vrr, 0, bitdepth, 10"
            "DP-1, 3840x2160@119.88, 2560x0, 1, vrr, 1, bitdepth, 10"
            "DP-2, 2560x1440@165.00, 6400x0, 1, vrr, 1, transform, 3"
          ];
        }
      ];

      system.stateVersion = "25.05";
    };
}
