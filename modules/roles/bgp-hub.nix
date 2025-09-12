{ config, ... }:
{
  flake.modules.nixos.role_bgp-hub.imports = with config.flake.modules.nixos; [
    bgp-hub
  ];
}
