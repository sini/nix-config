{ config, ... }:
{
  flake.modules.nixos.role_vault.imports = with config.flake.modules.nixos; [
    vault
  ];
}
