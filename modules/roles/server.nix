{ config, ... }:
{
  flake.modules.nixos.role_server.imports = with config.flake.modules.nixos; [
    acme
    media-data-share
    network-boot
    server
    alloy
  ];
}
