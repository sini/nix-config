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
        hardware.networking.interfaces = [ "enp6s0" ];
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

      environment.systemPackages = with pkgs; [
        gitkraken
        krita
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
