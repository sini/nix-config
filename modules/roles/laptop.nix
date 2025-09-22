{ config, ... }:
{
  flake.role.laptop.imports = with config.flake.modules.nixos; [
    laptop
  ];
}
