{ config, ... }:
{
  flake.role.bgp-hub.imports = with config.flake.modules.nixos; [
    bgp-hub
  ];
}
