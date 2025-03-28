{
  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [ inputs.nixos-hardware.nixosModules.common-gpu-intel ];

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
      media.data-share.enable = true;
      rpcbind.enable = true; # needed for NFS
    };

    # ======================== DO NOT CHANGE THIS ========================
    system.stateVersion = "24.11";
    # ======================== DO NOT CHANGE THIS ========================
  };
}
