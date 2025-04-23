{
  pkgs,
  ...
}:
{

  node = {
    deployment.targetHost = "10.10.10.5";
    tags = [ "server" ];
  };

  # sops.secrets."network/eno1/mac" = {
  #   sopsFile = lib.custom.relativeToRoot "secrets/${config.networking.hostName}/secrets.yaml";
  # };

  facter.reportPath = ./facter.json;

  # topology.self = {
  #   hardware.info = "surge";
  #   services.k8s.name = "k8s";
  # };

  hardware.disk.raid = {
    enable = true;
    btrfs_profile = "single";
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
    media.data-share.enable = true;
    rpcbind.enable = true; # needed for NFS
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
