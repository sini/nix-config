{ config, ... }:
{
  flake.role.metrics-ingester.imports = with config.flake.modules.nixos; [
    loki
    prometheus
  ];
}
