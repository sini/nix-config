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
  withSystem,
  ...
}:
let
  inherit (den.lib.policy) resolve;

  clusters = config.den.clusters;
in
{
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

    # Auto-include the entity-named aspect for each cluster (mirrors host
    # entity behaviour where host.aspect defaults to den.aspects.<name>).
    den.policies.cluster-aspect =
      { cluster, ... }:
      let
        aspect = den.aspects.${cluster.name} or null;
      in
      lib.optionals (aspect != null) [
        (den.lib.policy.include aspect)
      ];

    # ===========================================================================
    # Environment
    #
    # cluster-to-nixidy: one nixidy environment per cluster, per system. Fires for
    # every cluster via den.schema.cluster.includes. The instantiate closure
    # collects the den-walked k8s-manifests modules for the cluster — every
    # cluster aspect, including nixidy-defaults (env/target/defaults), cluster-age
    # (sops/rekey), and the crds bridge (CRD types + bootstrap objects, built
    # from the `crds` quirk in the nixidy battery) — and assembles the nixidy env.
    #
    # Looping config.systems keeps the per-system keying that flake.packages and
    # the agenix battery rely on (nixidyEnvs.<system>.<env>); the instantiate
    # handler recomputes `modules` per spec from the cluster scope.
    # ===========================================================================
    den.policies.cluster-to-nixidy =
      { cluster, environment, ... }:
      # lib.unique: config.systems carries duplicates inside the den pipeline
      # (hosts append their systems to the flake-parts list). The old genAttrs
      # deduped via attr keys; map must dedupe explicitly or applyInstantiates
      # warns on colliding nixidyEnvs.<system>.<env> specs.
      map (
        system:
        den.lib.policy.instantiate {
          inherit (cluster) name;
          class = "k8s-manifests";
          # Note: `system` is deliberately NOT set on the spec. The closure below
          # captures it via withSystem, and the path is already system-qualified
          # via intoAttr. Setting spec.system would make den inject a
          # { nixpkgs.hostPlatform = system; } module, which nixidy rejects.
          intoAttr = [
            "nixidyEnvs"
            system
            cluster.name
          ];
          instantiate =
            { modules, ... }:
            withSystem system (
              { pkgs, ... }:
              inputs.nixidy.lib.mkEnv {
                # Extend with the flake's default overlay so manifest aspects can
                # reach the repo's own packages via pkgs.local (e.g. the cilium
                # CRD aspect reusing pkgs.local.cni-plugin-cilium.src).
                pkgs = pkgs.extend config.flake.overlays.default;
                charts =
                  (inputs.nixhelm.chartsDerivations.${system} or { })
                  // (config.flake.chartsDerivations.${system} or { });
                # den-collected kubernetes-class modules for this cluster
                inherit modules;
              }
            );
        }
      ) (lib.unique config.systems);

    den.schema.environment.includes = [ den.policies.env-to-clusters ];
    den.schema.cluster.includes = [
      den.policies.cluster-to-nixidy
      den.policies.cluster-aspect
    ];
  };
}
