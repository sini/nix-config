{ config, ... }:
{
  flake.modules.nixos.role_kubernetes = {
    imports = with config.flake.modules.nixos; [
      kubernetes
      cilium-bgp
    ];
  };
}
