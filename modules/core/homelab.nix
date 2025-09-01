{ config, lib, ... }:
let
  hosts = lib.attrsets.mapAttrs' (
    hostname: hostConfig: (lib.attrsets.nameValuePair hostConfig.ipv4 [ hostname ])
  ) config.flake.hosts;
  sshKnownHosts = lib.attrsets.mapAttrs' (
    hostname: hostConfig:
    (lib.attrsets.nameValuePair hostname {
      hostNames = [
        hostname
        "${hostname}.json64.dev"
        hostConfig.ipv4
      ];
      publicKey = hostConfig.public_key;
    })
  ) config.flake.hosts;
in
{
  flake.modules.nixos.homelab = {
    networking.hosts = hosts;
    services.openssh.knownHosts = sshKnownHosts;
  };
}
