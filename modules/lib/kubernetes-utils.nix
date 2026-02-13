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

    getNamespaceList =
      config: lib.unique (map (app: app.namespace) (builtins.attrValues config.applications));

    # Helper to create SOPS secret reference functions for a given environment
    mkSecretHelpers = environment: {
      secretFor = secretName: "ref+sops://${environment.kubernetes.secretsFile}#${secretName}";
      secretInlineFor = secretName: "ref+sops://${environment.kubernetes.secretsFile}#${secretName}+";
      secretBase64For =
        secretName: "ref+sops://${environment.kubernetes.secretsFile}#${secretName}?encode=base64";
    };
  };
}
