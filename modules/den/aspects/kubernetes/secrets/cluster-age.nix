# Cluster age/sops secrets — cluster-baseline aspect.
#
# Imports the agenix-rekey-to-sops bridge and the custom generator types, then
# configures per-cluster sops output and rekey storage. Wired into
# den.schema.cluster.includes so it fires for every cluster; folding the two
# supporting modules in here is the point of making this an aspect — the
# cluster-to-nixidy instantiate stays free of secrets concerns.
{ inputs, config, ... }:
let
  inherit (config.den) secretsConfig;

  clusterAgeAspect = {
    name = "secrets/cluster-age";
    k8s-manifests =
      { cluster, environment, ... }:
      {
        imports = [
          inputs.agenix-rekey-to-sops.sopsModules.default
          # Custom agenix-rekey generator types (standalone NixOS module)
          (import ../../secrets/_generators-module.nix)
        ];

        age = {
          sops.outputDir = cluster.secretPath + "/sops";
          rekey = {
            recipientIdentifier = "${environment.name}-${cluster.name}";
            storageMode = "local";
            generatedSecretsDir = cluster.secretPath + "/generated";
            localStorageDir = cluster.secretPath + "/rekeyed";
            inherit (secretsConfig) masterIdentities;
          };
        };
      };
  };
in
{
  den.schema.cluster.includes = [ clusterAgeAspect ];
}
