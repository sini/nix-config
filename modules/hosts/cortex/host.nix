{ config, ... }:
{
  flake.hosts.cortex = {
    unstable = true;
    ipv4 = "10.10.10.9";
    roles = [
      "workstation"
      "gaming"
    ];
    extra_modules = with config.flake.modules.nixos; [
      cpu-amd
      gpu-amd
      gpu-nvidia
      disk-single
      {
        hardware.disk.single.device_id = "nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X704630A";
        hardware.networking.interface = "enp6s0";
      }
    ];
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDFFLWZzC91VBRxi3KwvRm7pI2vaAItIf9Nnd3Eifkmc root@cortex";
    facts = ./facter.json;
  };

  flake.modules.nixos.host_cortex =
    {
      pkgs,
      ...
    }:
    {

      boot.kernelPackages = pkgs.linuxPackages_cachyos;

      systemd = {
        services.NetworkManager-wait-online.enable = false;
        network.wait-online.enable = false;
      };

      networking = {
        domain = "json64.dev";
        networkmanager.enable = false;
        firewall.enable = false;
      };

      environment.systemPackages = with pkgs; [
        # Any particular packages only for this host
        wget
        vim
        git
        gitkraken
        krita
        pavucontrol
        brightnessctl
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

      # ======================== DO NOT CHANGE THIS ========================
      system.stateVersion = "25.05";
      # ======================== DO NOT CHANGE THIS ========================
    };
}
