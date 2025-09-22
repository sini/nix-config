{ config, ... }:
{
  flake.role.kubernetes = {
    imports = with config.flake.modules.nixos; [
      kubernetes
      cilium-bgp
    ];
  };
}
