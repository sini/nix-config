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
          );

        # Sort master hosts by hostname for deterministic selection
        sortedMasterHosts = builtins.sort (a: b: a.hostname < b.hostname) (
          lib.mapAttrsToList (hostname: hostConfig: hostConfig // { inherit hostname; }) masterHosts
        );
      in
      if sortedMasterHosts != [ ] then
        let
          masterHost = builtins.head sortedMasterHosts;
        in
        # masterHost.tags.kubernetes-internal-ip or
        (builtins.head masterHost.ipv4)
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
