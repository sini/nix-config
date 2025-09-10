{ config, ... }:
{
  flake.modules.nixos.role_metrics-ingester.imports = with config.flake.modules.nixos; [
    loki
  ];
}
