{ config, lib, ... }:
let
  hosts = lib.attrsets.mapAttrs' (
    hostname: hostConfig:
    let
      targetEnv = config.flake.environments.${hostConfig.environment or "homelab"};
    in
    (lib.attrsets.nameValuePair hostConfig.ipv4 [
      hostname
      "${hostname}.${targetEnv.domain}"
    ])
  ) config.flake.hosts;
  sshKnownHosts = lib.attrsets.mapAttrs' (
    hostname: hostConfig:
    let
      targetEnv = config.flake.environments.${hostConfig.environment or "homelab"};
    in
    (lib.attrsets.nameValuePair hostname {
      hostNames = [
        hostname
        "${hostname}.${targetEnv.domain}"
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
