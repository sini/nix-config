{
  ...
}:
# let
#   inherit (lib.${namespace}) enabled;
# in
{
  imports = [
    ./boot.nix
    ./disks.nix
    ./hardware.nix
    ./network.nix
    ./specializations.nix
  ];

  # Enable Bootloader
  system.boot.efi.enable = true;
  # system.boot.bios.enable = true;

  # system.battery.enable = true; # Only for laptops, they will still work without it, just improves battery life

  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
  ];

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
