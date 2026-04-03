{
  den,
  config,
  lib,
  ...
}:
let
  allHosts = config.hosts or { };
  allEnvironments = config.environments or { };

  hostsMap =
    allHosts
    |> lib.attrsets.filterAttrs (_: h: h.ipv4 != [ ])
    |> lib.attrsets.mapAttrs' (
      hostname: hostConfig:
      let
        env = allEnvironments.${hostConfig.environment};
        ip = builtins.head hostConfig.ipv4;
      in
      lib.attrsets.nameValuePair ip [
        hostname
        "${hostname}.${env.name}.${env.domain}"
      ]
    );

  sshKnownHosts =
    allHosts
    |> lib.attrsets.mapAttrs' (
      hostname: hostConfig:
      let
        env = allEnvironments.${hostConfig.environment};
        ipList = hostConfig.ipv4;
      in
      lib.attrsets.nameValuePair hostname {
        hostNames = [
          hostname
          "${hostname}.${env.name}.${env.domain}"
        ]
        ++ ipList
        ++ (if ipList == [ ] then [ "${hostname}.ts.json64.dev" ] else [ ]);
        publicKeyFile = hostConfig.public_key;
      }
    );
in
{
  den.aspects.hosts-file = den.lib.perHost (_: {
    nixos =
      { config, lib, ... }:
      {
        networking.hosts = lib.attrsets.filterAttrs (
          _ip: hostnames: !(builtins.elem config.networking.hostName hostnames)
        ) hostsMap;

        services.openssh.knownHosts = lib.attrsets.filterAttrs (
          hostname: _: hostname != config.networking.hostName
        ) sshKnownHosts;
      };
  });
}
