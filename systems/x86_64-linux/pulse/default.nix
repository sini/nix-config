{ pkgs, config, ... }:
{
  imports = [
    ./disks.nix
    # ./hardware-configuration.nix
  ];

  config.facter.reportPath = ./facter.json;
  # Enable Bootloader
  system.boot.efi.enable = true;

  # boot.kernelParams = [ "ip=dhcp" ];
  # boot.initrd = {
  #   availableKernelModules = [ "r8169" ];
  #   systemd.users.root.shell = "/bin/cryptsetup-askpass";
  #   network = {
  #     enable = true;
  #     ssh = {
  #       enable = true;
  #       port = 22;
  #       authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOa9kFogEBODAU4YVs4hxfVx3b5ryBzct4HoAHgwPio" ];
  #       hostKeys = [ "/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key" ];
  #     };
  #   };
  # };

  # system.battery.enable = true; # Only for laptops, they will still work without it, just improves battery life

  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
  ];

  suites.common.enable = true; # Enables the basics, like audio, networking, ssh, etc.

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
