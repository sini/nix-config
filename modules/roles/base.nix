{ config, ... }:
{
  flake.modules.nixos.role_base.imports = with config.flake.modules.nixos; [
    agenix
    avahi
    deterministic-uids
    disko
    facter
    firmware
    locale
    networking
    nix
    nixpkgs
    openssh
    ssd
    sudo
    systemd-boot
    time

    # apps/shell
    shell

    # users
    users
  ];
}
