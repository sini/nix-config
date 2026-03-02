{
  lib,
  config,
  rootPath,
  ...
}:
{
  flake.lib.kubernetes-utils = {
    findEnvironmentByName =
      name:
      let
        environments = config.flake.environments or { };
      in
      environments.${name} or null;

    findClusterMaster =
      environment:
      let
        hosts = config.flake.hosts;
        masterHosts =
          hosts
          |> lib.attrsets.filterAttrs (
            _hostname: hostConfig:
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
        _hostname: hostConfig:
        (builtins.elem "kubernetes" (hostConfig.roles or [ ]))
        && (hostConfig.environment == environment.name)
      );

    # Helper to create SOPS secret reference functions for a given environment
    mkSecretHelpers =
      environment:
      let
        credentialsEnv =
          if environment.kubernetes.sso.credentialsEnvironment != null then
            environment.kubernetes.sso.credentialsEnvironment
          else
            environment.name;
      in
      {
        for = secretName: "ref+sops://${environment.kubernetes.secretsFile}#${secretName}";
        forInlineFor = secretName: "ref+sops://${environment.kubernetes.secretsFile}#${secretName}+";
        forOidcService =
          name:
          "ref+sops://${rootPath}/.secrets/env/${credentialsEnv}/oidc/${name}-oidc-client-secret.enc.yaml#${name}-oidc-client-secret";
        oidcIssuerFor =
          clientID:
          let
            pattern =
              if environment.kubernetes.sso.issuerPattern != null then
                environment.kubernetes.sso.issuerPattern
              else
                let
                  credEnv = config.flake.lib.kubernetes-utils.findEnvironmentByName credentialsEnv;
                  domain = if credEnv != null then credEnv.domain else environment.domain;
                in
                "https://idm.${domain}/oauth2/openid/{clientID}";
          in
          lib.replaceStrings [ "{clientID}" ] [ clientID ] pattern;
      };
  };
}
