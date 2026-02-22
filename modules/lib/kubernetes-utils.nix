{ lib, config, ... }:
{
  flake.lib.kubernetes-utils = {
    findClusterMaster =
      environment:
      let
        hosts = config.flake.hosts;
        masterHosts =
          hosts
          |> lib.attrsets.filterAttrs (
            hostname: hostConfig:
            (builtins.elem "kubernetes" (hostConfig.roles or [ ]))
            && (hostConfig.environment == environment.name)
          )
          |> lib.attrsets.filterAttrs (
            hostname: hostConfig: builtins.elem "kubernetes-master" (hostConfig.roles or [ ])
          );
      in
      if lib.length (lib.attrNames masterHosts) > 0 then
        let
          masterHost = lib.head (lib.attrValues masterHosts);
        in
        masterHost.tags.kubernetes-internal-ip or (builtins.head masterHost.ipv4)
      else
        null;

    findKubernetesNodes =
      environment:
      let
        hosts = config.flake.hosts;
      in
      hosts
      |> lib.attrsets.filterAttrs (
        hostname: hostConfig:
        (builtins.elem "kubernetes" (hostConfig.roles or [ ]))
        && (hostConfig.environment == environment.name)
      );

    # Helper to create SOPS secret reference functions for a given environment
    mkSecretHelpers = environment: {
      for = secretName: "ref+sops://${environment.kubernetes.secretsFile}#${secretName}";
      forInlineFor = secretName: "ref+sops://${environment.kubernetes.secretsFile}#${secretName}+";
    };
  };
}
