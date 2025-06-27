{ config, ... }:
{
  flake.modules.nixos.core.imports = with config.flake.modules.nixos; [
    agenix
    disko
    facter
    fwupd
    nix
    #apps shell
    shell
  ];
}
