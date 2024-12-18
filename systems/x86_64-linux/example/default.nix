{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Enable Bootloader
  system.boot.efi.enable = true;
  # system.boot.bios.enable = true;

  # system.battery.enable = true; # Only for laptops, they will still work without it, just improves battery life

  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
  ];

  suites.common.enable = true; # Enables the basics, like audio, networking, ssh, etc.

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
