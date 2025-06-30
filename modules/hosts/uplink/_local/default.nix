{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-cpu-amd-zenpower
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-gpu-intel
  ];
  # inherit (nixos-hardware.nixosModules)

  config = {

    # Enable remote vscode...
    # topology.self = {
    #   hardware.info = "burst";
    #   services.k8s.name = "k8s";
    # };

    hardware = {
      intelgpu.driver = "xe";

      disk.single = {
        enable = true;
        device_id = "nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
      };

      networking = {
        enable = true;
        interface = "enp4s0";
      };
    };

    programs.dconf.enable = true;

    # Use cachyOS kernel, server variant: https://wiki.cachyos.org/features/kernel/
    # boot.kernelPackages = inputs.chaotic.legacyPackages.x86_64-linux.linuxPackages_cachyos;

    boot.kernelPackages = pkgs.linuxPackages_latest;

    environment.systemPackages = with pkgs; [
      # Any particular packages only for this host
      wget
      btop
      vim
      git
    ];

    powerManagement = {
      enable = true;
      cpuFreqGovernor = "ondemand";
    };

    # ======================== DO NOT CHANGE THIS ========================
    system.stateVersion = "25.05";
    # ======================== DO NOT CHANGE THIS ========================
  };
}
