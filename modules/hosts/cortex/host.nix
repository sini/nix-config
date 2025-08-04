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
    public_key = "./ssh_host_ed25519_key.pub";
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

      # ======================== DO NOT CHANGE THIS ========================
      system.stateVersion = "25.05";
      # ======================== DO NOT CHANGE THIS ========================
    };
}
