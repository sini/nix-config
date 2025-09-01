{ config, lib, ... }:
let
  # TODO: Replace hardcoded FQDN with a scoped variable
  hosts = lib.attrsets.mapAttrs' (
    hostname: hostConfig:
    (lib.attrsets.nameValuePair hostConfig.ipv4 [
      hostname
      "${hostname}.json64.dev"
    ])
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
