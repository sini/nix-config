{ config, ... }:
{
  flake.modules.nixos.role_base.imports = with config.flake.modules.nixos; [
    agenix
    deterministic-uids
    disko
    facter
    fwupd
    locale
    nix
    nixpkgs
    openssh
    sudo
    time

    # apps/shell
    shell

    # users
    users
  ];
}
