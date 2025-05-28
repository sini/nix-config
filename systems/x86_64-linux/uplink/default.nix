{
  inputs,
  config,
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
    facter.reportPath = ./facter.json;

    node = {
      deployment.targetHost = "10.10.10.1";
      tags = [ "server" ];
    };

    # Enable remote vscode...
    programs.nix-ld.enable = true;

    # topology.self = {
    #   hardware.info = "burst";
    #   services.k8s.name = "k8s";
    # };

    hardware = {
      intelgpu.driver = "xe";

      gpu.intel = {
        enable = true;
        device_id = "22182";
      };

      disk.single = {
        enable = true;
        device_id = "nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
      };

      networking = {
        enable = true;
        interface = "enp4s0";
      };
    };

    services.ssh.enable = true;
    programs.dconf.enable = true;

    system = {
      locale.enable = true;
      nix.enable = true;
      security.doas.enable = true;
    };

    # Use cachyOS kernel, server variant: https://wiki.cachyos.org/features/kernel/
    # boot.kernelPackages = inputs.chaotic.legacyPackages.x86_64-linux.linuxPackages_cachyos;

    boot.kernelPackages = pkgs.linuxPackages_latest;

    time.timeZone = "America/Los_Angeles";
    i18n.defaultLocale = "en_US.UTF-8";

    environment.systemPackages = with pkgs; [
      # Any particular packages only for this host
      wget
      btop
      vim
      git
      doas
      doas-sudo-shim
    ];

    powerManagement = {
      enable = true;
      cpuFreqGovernor = "ondemand";
    };

    services = {
      podman.enable = true;
      fstrim.enable = true;
      custom.media.data-share.enable = true;
      rpcbind.enable = true; # needed for NFS
      #scx.enable = true;
    };

    # ======================== DO NOT CHANGE THIS ========================
    system.stateVersion = "25.05";
    # ======================== DO NOT CHANGE THIS ========================
  };
}
