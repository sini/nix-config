{
  flake.lib.kubernetes-secrets = {
    # Helper to create SOPS secret reference functions for a given environment
    mkSecretHelpers = environment: {
      secretFor = secretName: "ref+sops://${environment.kubernetes.secretsFile}#${secretName}";
      secretInlineFor = secretName: "ref+sops://${environment.kubernetes.secretsFile}#${secretName}+";
      secretBase64For =
        secretName: "ref+sops://${environment.kubernetes.secretsFile}#${secretName}?encode=base64";
    };
  };
}
