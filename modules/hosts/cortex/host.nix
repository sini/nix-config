{
  flake.hosts.cortex = {
    ipv4 = [ "10.9.2.1" ];
    ipv6 = [ "fd64:0:1::5/64" ];
    environment = "dev";
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
      #"gpu-nvidia"
      #"gpu-nvidia-prime"
      "gpu-nvidia-vfio"
      "zfs-disk-single"
      "performance"
      "network-manager"
      "microvm"
      "microvm-cuda"
      "windows-vfio"
      "gamedev"
      "easyeffects"
      "media-data-share"
      "cad"
      "podman"
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

        boot.kernelPackages = pkgs.linuxPackages_cachyos.cachyOverride { mArch = "ZEN4"; };

        hardware.disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X704630A";

        hardware.networking.interfaces = [ "enp8s0" ];

        # For Network Manager TODO: RENAME
        hardware.networking.unmanagedInterfaces = [
          "enp8s0"
          "br0"
        ];

        # Enable HDR support
        # TODO: move to hardware module
        chaotic.hdr = {
          enable = true;
          specialisation.enable = false;
        };

        # Host-specific home-manager configuration
        home-manager.sharedModules = [
          {
            wayland.windowManager.hyprland.settings.monitor = [
              "DP-2, 2560x1440@165.00, 0x0, 1, vrr, 1, transform, 1"
              "DP-1, 3840x2160@119.88, 2560x0, 1, vrr, 1, bitdepth, 10"
              "DP-3, 2560x2880@59.98, 6400x0, 1.25, vrr, 0, bitdepth, 10"
            ];
          }
        ];

        impermanence = {
          wipeRootOnBoot = true;
          wipeHomeOnBoot = false;
        };

        system.stateVersion = "25.05";
      };
  };
}
