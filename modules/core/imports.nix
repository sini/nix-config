{ config, ... }:
{
  flake.modules.nixos.core.imports = with config.flake.modules.nixos; [
    agenix
    deterministic-uids
    disko
    facter
    fwupd
    nix
    nixpkgs

    # apps/shell
    shell
    doas

    # users
    users
  ];
}
