{
  pkgs,
  ...
}:
# let
#   inherit (lib.${namespace}) enabled;
# in
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

  suites.common.enable = true; # Enables the basics, like audio, networking, ssh, etc.

  services = {
    rpcbind.enable = true; # needed for NFS
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
