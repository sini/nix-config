{
  hosts.blade = {
    # No static networking config - NetworkManager handles DHCP dynamically
    # Accessed via Tailscale: blade.ts.json64.dev
    environment = "dev";

    channel = "nixpkgs-master";

    system-owner = "sini";
    system-access-groups = [ "workstation-access" ];

    excluded-features = [
      # "wireless" # NetworkManager handles WiFi instead of wpa_supplicant
    ];

    extra-features = [
      # Composite features (formerly roles)
      "workstation"
      "laptop"
      "gaming"
      "dev"
      "dev-gui"
      "media"

      # Hardware and system features
      "cpu-intel"
      "gpu-intel"
      "gpu-nvidia"
      "gpu-nvidia-prime"
      "zfs-disk-single"
      "network-manager"
      "razer"
      # "gamedev"
      "performance"
      "tailscale"
      "discord"
      "network-boot"
      "wireless-initrd"
      # "initrd-bootstrap-keys" # Generate keys only
    ];

    users = {
      sini = {
        extra-features = [
          "spotify-player"
          "waybar"
          "swaync"
          "hypridle"
          "hyprland-split-monitors"
        ];
      };
      shuo = {
        extra-features = [
          "firefox"
          "steam"
          "spicetify"
        ];
      };
    };

    feature-settings.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-CT4000P3PSSD8_2431E8BD13D9";

    facts = ./facter.json;

    systemConfiguration =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-x86_64-v4;

        system.stateVersion = "25.05";
      };
  };
}
