{ pkgs, ... }:
{
  imports = [
    ../shared/boot.nix
  ];

  facter.reportPath = ./facter.json;

  hardware.disk.single.enable = true;
  hardware.disk.single.swap_size = 65536; # 64GB

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
