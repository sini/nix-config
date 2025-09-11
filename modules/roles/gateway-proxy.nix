{ config, ... }:
{
  flake.modules.nixos.role_gateway-proxy.imports = with config.flake.modules.nixos; [
    bgp-uplink
  ];
}
