{ config, ... }:
{
  flake.modules.nixos.role_server.imports = with config.flake.modules.nixos; [
    media-data-share
    network-boot
    server
    role_dev
    promtail
  ];
}
