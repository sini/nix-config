{ ... }:
{
  flake.hosts.cortex = {
    ipv4 = [ "10.10.10.9" ];
    ipv6 = [ "fd64:0:1::5/64" ];
    environment = "dev";
    roles = [
      "workstation"
      "gaming"
      "dev"
      "dev-gui"
      "media"
    ];
    features = [
      "cpu-amd"
      "gpu-amd"
      "gpu-nvidia"
      "gpu-nvidia-prime"
      "gpu-nvidia-vfio"
      "disk-single"
      "performance"
    ];
    users = {
      "sini" = {
        "features" = [
          "spotify-player"
        ];
      };
    };
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        # Enable NetworkManager for managing network interfaces
        networking.networkmanager.enable = true;
        hardware.disk.single.device_id = "nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X704630A";
        hardware.networking.interfaces = [ "enp8s0" ];

        boot.kernelPackages = pkgs.linuxPackages_cachyos; # TODO: https://github.com/chaotic-cx/nyx/issues/1178

        # use TCP BBR has significantly increased throughput and reduced latency for connections
        boot.kernelModules = [
          "ntsync"
          "it87" # Fan options
        ];
        # Enable fan sensors...
        boot.kernelParams = [
          # ACPI & Power Management
          "acpi_osi=Linux" # Set ACPI OS interface to Linux
          "acpi=force" # Force ACPI
          "acpi_enforce_resources=lax"
          "resume_offset=0" # Set resume offset to 0

          # Performance & Security
          "mitigations=off" # Disable CPU vulnerabilities mitigations (security trade-off)
          "nowatchdog" # Disable watchdog timer
          "nmi_watchdog=0" # Disable NMI watchdog
          "split_lock_detect=off" # Disable split lock detection
          "pcie_aspm=off" # Disable PCIe Active State Power Management
        ];

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

        # Host-specific home-manager configuration
        home-manager.sharedModules = [
          {
            wayland.windowManager.hyprland.settings.monitor = [
              "DP-3, 2560x2880@59.98, 0x0, 1.25, vrr, 0, bitdepth, 10"
              "DP-1, 3840x2160@119.88, 2048x0, 1, vrr, 1, bitdepth, 10"
              "DP-2, 2560x1440@165.00, 5888x0, 1, vrr, 1, transform, 3"
            ];
          }
        ];

        system.stateVersion = "25.05";
      };
  };
}
