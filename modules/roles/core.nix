{ config, ... }:
{
  flake.modules.nixos.core.imports = with config.flake.modules.nixos; [
    core.agenix
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
