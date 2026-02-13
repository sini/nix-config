{ lib, ... }:
{
  flake.lib.kubernetes-utils = {
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
