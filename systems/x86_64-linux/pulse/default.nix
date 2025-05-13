{
  pkgs,
  unstable,
  namespace,
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

  boot.kernelPackages = unstable.linuxPackages_latest;

  facter.reportPath = ./facter.json;

  # topology.self = {
  #   hardware.info = "pulse";
  #   services.k8s.name = "k8s";
  # };

  hardware.disk.single.enable = true;

  hardware.networking.enable = true;

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
