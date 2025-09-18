{ config, lib, ... }:
let
  hosts = lib.attrsets.mapAttrs' (
    hostname: hostConfig:
    let
      targetEnv = config.flake.environments.${hostConfig.environment or "homelab"};
      # Convert ipv4 to list if it's a string, otherwise use as-is
      ipList = if builtins.isString hostConfig.ipv4 then [ hostConfig.ipv4 ] else hostConfig.ipv4;
    in
    (lib.attrsets.nameValuePair (builtins.head ipList) [
      hostname
      "${hostname}.${targetEnv.domain}"
    ])
  ) config.flake.hosts;

  sshKnownHosts = lib.attrsets.mapAttrs' (
    hostname: hostConfig:
    let
      targetEnv = config.flake.environments.${hostConfig.environment or "homelab"};
      # Convert ipv4 to list if it's a string, otherwise use as-is
      ipList = if builtins.isString hostConfig.ipv4 then [ hostConfig.ipv4 ] else hostConfig.ipv4;
    in
    (lib.attrsets.nameValuePair hostname {
      hostNames = [
        hostname
        "${hostname}.${targetEnv.domain}"
      ]
      ++ ipList;
      publicKey = hostConfig.public_key;
    })
  ) config.flake.hosts;
in
{
  flake.modules.nixos.hosts =
    { config, lib, ... }:
    {
      networking.hosts = lib.attrsets.filterAttrs (
        ip: hostnames: !(builtins.elem config.networking.hostName hostnames)
      ) hosts;

      services.openssh.knownHosts = lib.attrsets.filterAttrs (
        hostname: _: hostname != config.networking.hostName
      ) sshKnownHosts;
    };
}
