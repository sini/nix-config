{ config, lib, ... }:
let
  hosts =
    config.flake.hosts
    |> lib.attrsets.mapAttrs' (
      hostname: hostConfig:
      let
        targetEnv = config.flake.environments.${hostConfig.environment};
        ipList = hostConfig.ipv4;
      in
      lib.attrsets.nameValuePair (builtins.head ipList) [
        hostname
        "${hostname}.${targetEnv.domain}"
      ]
    );

  sshKnownHosts =
    config.flake.hosts
    |> lib.attrsets.mapAttrs' (
      hostname: hostConfig:
      let
        targetEnv = config.flake.environments.${hostConfig.environment};
        ipList = hostConfig.ipv4;
      in
      lib.attrsets.nameValuePair hostname {
        hostNames = [
          hostname
          "${hostname}.${targetEnv.domain}"
        ]
        ++ ipList;
        publicKey = hostConfig.public_key;
      }
    );
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
