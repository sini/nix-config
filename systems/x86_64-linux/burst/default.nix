{
  ...
}:
# let
#   inherit (lib.${namespace}) enabled;
# in
{
  imports = [
    ./boot.nix
    # ./hardware.nix
    # ./network.nix
    # ./specializations.nix
  ];

  facter.reportPath = ./facter.json;

  hardware.disk.single.enable = true;
  hardware.disk.single.swap_size = 65536; # 64GB

  # Enable Bootloader
  system.boot.efi.enable = true;

  # environment.systemPackages = with pkgs; [
  #   # Any particular packages only for this host
  # ];

  suites.common.enable = true; # Enables the basics, like audio, networking, ssh, etc.

  nix.settings = {
    cores = 8;
    max-jobs = 8;
  };

  services = {
    rpcbind.enable = true; # needed for NFS
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
