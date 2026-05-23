# Builds /etc/hosts and SSH known_hosts from den host declarations.
# TODO: uses top-level config.hosts/config.environments from legacy module --
# will need reworking once den exposes cross-host discovery natively.
{
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;

  hosts =
    config.den.hosts.x86_64-linux or { }
    |> lib.filterAttrs (_: hostCfg: (hostCfg.ipv4 or [ ]) != [ ])
    |> lib.mapAttrs' (
      hostname: hostCfg:
      let
        targetEnv = environments.${hostCfg.environment};
        ipList = hostCfg.ipv4;
      in
      lib.nameValuePair (builtins.head ipList) [
        hostname
        "${hostname}.${targetEnv.name}.${targetEnv.domain}"
      ]
    );

  sshKnownHosts =
    config.den.hosts.x86_64-linux or { }
    |> lib.mapAttrs' (
      hostname: hostCfg:
      let
        targetEnv = environments.${hostCfg.environment};
        ipList = hostCfg.ipv4 or [ ];
      in
      lib.nameValuePair hostname {
        hostNames = [
          hostname
          "${hostname}.${targetEnv.name}.${targetEnv.domain}"
        ]
        ++ ipList
        ++ (if ipList == [ ] then [ "${hostname}.ts.json64.dev" ] else [ ]);
        publicKeyFile = hostCfg.public_key;
      }
    );
in
{
  den.aspects.network.hosts = {
    nixos =
      { config, ... }:
      {
        networking.hosts = lib.filterAttrs (
          _ip: hostnames: !(builtins.elem config.networking.hostName hostnames)
        ) hosts;

        services.openssh.knownHosts = lib.filterAttrs (
          hostname: _: hostname != config.networking.hostName
        ) sshKnownHosts;
      };
  };
}
