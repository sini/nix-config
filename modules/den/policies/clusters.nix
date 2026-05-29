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
  options.den.clusters = schemaLib.mkInstanceRegistry den.schema.cluster {
    description = "Cluster definitions for fleet topology and K8s service resolution";
    derive =
      clusters:
      lib.mapAttrs (
        _: c:
        lib.optionalAttrs
          (c.secretPath != null && builtins.pathExists "${c.secretPath}/cluster-sops-age-key.pub")
          {
            sopsAgeRecipient = builtins.readFile "${c.secretPath}/cluster-sops-age-key.pub";
          }
      ) clusters;
    extraModules = [
      (_: {
        options.sopsAgeRecipient = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          readOnly = true;
          internal = true;
          description = "Derived SOPS age recipient public key from cluster secretPath";
        };
      })
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

    # TODO(den-ag): cluster-to-hosts causes duplicate instantiate specs because
    # resolve.to "host" re-resolves the host entity (triggering schema includes
    # like host-to-colmena a second time). den-ag's graph-native `edge` primitive
    # will link existing host nodes into the cluster scope without re-resolution.
    # Until then, hosts use config.den.clusters registry lookup for cluster data.
    #
    # den.policies.cluster-to-hosts =
    #   { cluster, ... }:
    #   let
    #     allHosts = lib.concatMap (
    #       system:
    #       lib.map (hostName: den.hosts.${system}.${hostName}) (
    #         builtins.attrNames (den.hosts.${system} or { })
    #       )
    #     ) (builtins.attrNames (den.hosts or { }));
    #
    #     matchesCluster =
    #       h:
    #       let
    #         inEnv = (h.environment or "prod") == cluster.environment;
    #         roleAspect = den.aspects.services.${cluster.role} or null;
    #         hasRole = cluster.role != null && roleAspect != null && h.hasAspect roleAspect;
    #       in
    #       inEnv && hasRole;
    #
    #     matchedHosts =
    #       if cluster.hosts != null then
    #         builtins.filter (h: builtins.elem h.name cluster.hosts) allHosts
    #       else
    #         builtins.filter matchesCluster allHosts;
    #   in
    #   lib.map (h: resolve.to "host" { host = h; }) matchedHosts;

    den.schema.environment.includes = [ den.policies.env-to-clusters ];
    # den.schema.cluster.includes = [ den.policies.cluster-to-hosts ];
  };
}
