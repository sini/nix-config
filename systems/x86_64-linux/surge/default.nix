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

  hardware.networking.enable = true;

  services.ssh.enable = true;
  programs.dconf.enable = true;

  system.nix.enable = true;
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
    rpcbind.enable = true; # needed for NFS
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
