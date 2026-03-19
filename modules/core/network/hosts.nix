{
  config,
  lib,
  ...
}:
let
  hosts =
    config.hosts
    |> lib.attrsets.filterAttrs (_: hostConfig: hostConfig.ipv4 != [ ])
    |> lib.attrsets.mapAttrs' (
      hostname: hostConfig:
      let
        targetEnv = config.environments.${hostConfig.environment};
        ipList = hostConfig.ipv4;
      in
      lib.attrsets.nameValuePair (builtins.head ipList) [
        hostname
        "${hostname}.${targetEnv.name}.${targetEnv.domain}"
      ]
    );

  sshKnownHosts =
    config.hosts
    |> lib.attrsets.mapAttrs' (
      hostname: hostConfig:
      let
        targetEnv = config.environments.${hostConfig.environment};
        ipList = hostConfig.ipv4;
      in
      lib.attrsets.nameValuePair hostname {
        hostNames = [
          hostname
          "${hostname}.${targetEnv.name}.${targetEnv.domain}"
        ]
        ++ ipList
        ++ (if ipList == [ ] then [ "${hostname}.ts.json64.dev" ] else [ ]);
        publicKeyFile = hostConfig.public_key;
      }
    );
in
{
  features.hosts.linux =
    {
      config,
      lib,
      ...
    }:
    {
      networking.hosts = lib.attrsets.filterAttrs (
        _ip: hostnames: !(builtins.elem config.networking.hostName hostnames)
      ) hosts;

      services.openssh.knownHosts = lib.attrsets.filterAttrs (
        hostname: _: hostname != config.networking.hostName
      ) sshKnownHosts;
    };
}
