{
  pkgs,
  ...
}:
{
  node = {
    deployment.targetHost = "10.10.10.3";
    tags = [
      "server"
      # "kubernetes"
    ];
  };

  networking.domain = "json64.dev";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  facter.reportPath = ./facter.json;

  hardware = {
    disk.longhorn = {
      enable = true;
      os_drive = {
        device_id = "nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
        swap_size = 8192;
      };
      longhorn_drive = {
        device_id = "nvme-Force_MP600_192482300001285610CF";
      };
    };

    gpu.amd.enable = true;

    networking.enable = true;
  };

  services.ssh.enable = true;
  programs.dconf.enable = true;

  system = {
    nix.enable = true;
    security.doas.enable = true;
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
    wget
    vim
    git
    doas
    doas-sudo-shim
  ];

  services = {
    # podman.enable = true;
    fstrim.enable = true;
    custom.media.data-share.enable = true;
    rpcbind.enable = true; # needed for NFS
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "25.05";
  # ======================== DO NOT CHANGE THIS ========================
}
