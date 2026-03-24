{
  hosts.blade = {
    # Wireless DHCP — interface auto-detected by wireless feature via facter
    networking.interfaces.wlp0s20f3.dhcp = "yes";
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
    feature-settings.linux-kernel.optimization = "x86_64-v4";

    facts = ./facter.json;
  };
}
