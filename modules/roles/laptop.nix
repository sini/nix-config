{ config, ... }:
{
  flake.modules.nixos.role_laptop.imports = with config.flake.modules.nixos; [
    laptop
  ];
}
