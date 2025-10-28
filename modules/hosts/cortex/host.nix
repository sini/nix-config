{ ... }:
{
  flake.hosts.cortex = {
    ipv4 = [ "10.10.10.9" ];
    ipv6 = [ "fd64:0:1::5/64" ];
    environment = "prod";
    roles = [
      "workstation"
      "gaming"
      "dev"
      "dev-gui"
      "media"
      "inference"
    ];
    features = [
      "cpu-amd"
      "gpu-amd"
      "network-boot"
      # TODO: cuda and rocm don't play well together, create a new microvm for cuda
      #"gpu-nvidia"
      #"gpu-nvidia-prime"
      "gpu-nvidia-vfio"
      "zfs-disk-single"
      "performance"
      "network-manager"
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
        hardware.disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X704630A";
        hardware.networking.interfaces = [ "enp8s0" ];
        # For Network Manager TODO: RENAME
        hardware.networking.unmanagedInterfaces = [
          "enp8s0"
          "br0"
        ];

        boot.kernelPackages = pkgs.linuxPackages_cachyos.cachyOverride { mArch = "ZEN4"; };

        chaotic.hdr = {
          enable = true;
          specialisation.enable = false;
        };

        # Enable fan sensors...
        # boot.kernelModules = [
        #   "it87" # Fan options
        # ];
        # boot.extraModprobeConfig = ''
        #   options it87 ignore_resource_conflict=1 force_id=0x8628
        # '';

        # environment.systemPackages = with pkgs; [
        #   lm_sensors
        # ];

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

        # impermanence = {
        #   enable = true;
        #   wipeRootOnBoot = true;
        #   wipeHomeOnBoot = true;
        # };

        system.stateVersion = "25.05";
      };
  };
}
