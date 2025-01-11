{ pkgs, ... }:
{
  imports = [
    ../shared/boot.nix
  ];

  facter.reportPath = ./facter.json;
  boot.supportedFilesystems = [ "ntfs" ];

  hardware.disk.raid = {
    enable = true;
    btrfs_profile = "single";
    swap_size = 65536; # 64GB
  };

  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
    wget
    vim
  ];

  services = {
    rpcbind.enable = true; # needed for NFS
  };

  suites.common.enable = true; # Enables the basics, like audio, networking, ssh, etc.

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
