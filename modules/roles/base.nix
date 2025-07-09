{ config, ... }:
{
  flake.modules.nixos.role_base.imports = with config.flake.modules.nixos; [
    agenix
    avahi
    deterministic-uids
    disko
    facter
    firmware
    home-manager
    home-core
    i18n
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
