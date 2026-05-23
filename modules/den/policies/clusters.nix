# Cluster resolution policy.
#
# Resolves cluster entities into the scope tree at environment level.
# Clusters with isEntity = true (set in schema/cluster.nix) get
# resolve.to into the environment scope.
{
  lib,
  den,
  config,
  inputs,
  ...
}:
let
  inherit (den.lib.policy) resolve;
  schemaLib = inputs.gen-schema.lib;

  clusters = config.den.clusters;
in
{
  options.den.clusters = schemaLib.mkInstanceRegistry den.schema "cluster" {
    description = "Cluster definitions for fleet topology and K8s service resolution";
    derive =
      clusters:
      lib.mapAttrs (
        _: c:
        lib.optionalAttrs (c.secretPath != null) {
          sopsAgeRecipient = builtins.readFile "${c.secretPath}/cluster-sops-age-key.pub";
        }
      ) clusters;
    extraModules = [
      (
        _:
        {
          options.sopsAgeRecipient = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            readOnly = true;
            internal = true;
            description = "Derived SOPS age recipient public key from cluster secretPath";
          };
        }
      )
    ];
  };

  config = {
    # environment -> clusters: resolve clusters whose environment matches.
    den.policies.env-to-clusters =
      { environment, ... }:
      lib.concatMap (
        clusterName:
        let
          cluster = clusters.${clusterName};
        in
        lib.optionals ((cluster.environment or "") == environment.name) [
          (resolve.to "cluster" {
            cluster = cluster // {
              name = clusterName;
            };
          })
        ]
      ) (builtins.attrNames clusters);

    den.schema.environment.includes = [ den.policies.env-to-clusters ];
  };
}
