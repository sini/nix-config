{ pkgs, ... }:
{
  imports = [
    ../shared/boot.nix
  ];

  facter.reportPath = ./facter.json;

  topology.self = {
    hardware.info = "surge";
    services.k8s.name = "k8s";
  };

  hardware.disk.raid = {
    enable = true;
    btrfs_profile = "single";
  };

  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
    wget
    vim
    git
  ];

  services = {
    rpcbind.enable = true; # needed for NFS
  };

  suites.common.enable = true; # Enables the basics, like audio, networking, ssh, etc.

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
