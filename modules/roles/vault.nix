{ config, ... }:
{
  flake.role.vault.imports = with config.flake.modules.nixos; [
    vault
  ];
}
