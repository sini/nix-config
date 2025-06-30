{ config, ... }:
{
  flake.modules.nixos.role_base.imports = with config.flake.modules.nixos; [
    agenix
    deterministic-uids
    disko
    facter
    firmware
    locale
    nix
    nixpkgs
    openssh
    sudo
    systemd-boot
    time

    # apps/shell
    shell

    # users
    users
  ];
}
