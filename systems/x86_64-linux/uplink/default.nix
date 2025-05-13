{
  inputs,
  config,
  pkgs,
  namespace,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-cpu-amd-zenpower
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    #inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-intel
  ];
  # inherit (nixos-hardware.nixosModules)

  config = {
    facter.reportPath = ./facter.json;

    node = {
      deployment.targetHost = "10.10.10.1";
      tags = [ "server" ];
    };

    # boot.kernelParams = [ "ip=10.10.10.1::10.10.0.1:255.255.0.0:uplink:enp4s0:on" ];

    # Enable remote vscode...
    programs.nix-ld.enable = true;

    # topology.self = {
    #   hardware.info = "burst";
    #   services.k8s.name = "k8s";
    # };

    hardware = {
      intelgpu.driver = "xe";

      gpu.intel-arc = {
        enable = true;
        device_id = "22182";
      };

      disk.single = {
        enable = true;
        device_id = "nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
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
    boot.kernelPackages = inputs.chaotic.legacyPackages.x86_64-linux.linuxPackages_cachyos-server;

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

    services = {
      podman.enable = true;
      fstrim.enable = true;
      ${namespace} = {
        media.data-share.enable = true;
      };
      rpcbind.enable = true; # needed for NFS
      #scx.enable = true;
    };

    # ======================== DO NOT CHANGE THIS ========================
    system.stateVersion = "24.11";
    # ======================== DO NOT CHANGE THIS ========================
  };
}
