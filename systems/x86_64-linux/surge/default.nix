{
  pkgs,
  unstable,
  namespace,
  ...
}:
{

  node = {
    deployment.targetHost = "10.10.10.5";
    tags = [
      "server"
      # "kubernetes"
      # "kubernetes-master"
    ];
  };

  boot.kernelPackages = unstable.linuxPackages_latest;

  facter.reportPath = ./facter.json;

  hardware.disk.single = {
    enable = true;
    device_id = "nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
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
  ];

  services = {
    podman.enable = true;
    fstrim.enable = true;
    ${namespace} = {
      media.data-share.enable = true;
    };
    rpcbind.enable = true; # needed for NFS
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
