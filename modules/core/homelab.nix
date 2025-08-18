{ config, lib, ... }:
let
  hosts = lib.attrsets.mapAttrs' (
    hostname: hostConfig: (lib.attrsets.nameValuePair hostConfig.ipv4 [ hostname ])
  ) config.flake.hosts;
in
{
  flake.modules.nixos.homelab = {
    networking.hosts = hosts;
  };
}
