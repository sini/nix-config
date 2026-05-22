# Cluster resolution policy.
#
# Resolves cluster entities into the scope tree at environment level.
# Clusters with isEntity = true (set in schema/cluster.nix) get
# resolve.to into the environment scope.
{
  lib,
  den,
  config,
  ...
}:
let
  inherit (den.lib.policy) resolve;

  clusters = config.clusters or { };
in
{
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
}
