# Nixidy assembly module — bridges den-collected kubernetes modules, CRD
# handling, and nixidy environment generation.
#
# Three concerns, in order below:
#   1. CRDs         — collect den aspects' CRDs, build them into nixidy values
#   2. Cluster      — per-cluster nixidy modules (hosts, sops, nixidy defaults)
#   3. Environment  — assemble a nixidy env per cluster, expose flake outputs
{
  config,
  den,
  inputs,
  withSystem,
  lib,
  ...
}:
let
  inherit (config.flake.meta) repo;

  clusters = config.den.clusters;
  environments = config.den.environments;
  aspects = config.den.aspects.kubernetes or { };
  secretsConfig = config.den.secretsConfig;

  # ===========================================================================
  # CRDs
  #
  # den aspects may declare a `crds` function. We collect them from the nested
  # kubernetes aspect tree and turn each into nixidy *values* (no generated
  # files, no IFD packages): a resource-type module for `applicationImports`
  # and the raw CRD manifests for the bootstrap app to deploy.
  # ===========================================================================

  # The aspect tree is nested (services/network/cilium, …) and a node may be
  # both an aspect (with `crds`) AND a parent of child aspects. Recurse it,
  # skipping structural/class/quirk keys, collecting every node with a `crds`
  # function keyed by its leaf name. (Mirrors host.nix's nodeModule.)
  inherit (den.lib.aspects.fx.keyClassification) structuralKeysSet;
  skipKey = k: structuralKeysSet ? ${k} || (den.classes or { }) ? ${k} || (den.quirks or { }) ? ${k};
  collectAspectsWithCrds =
    node:
    lib.foldlAttrs (
      acc: name: v:
      if !(builtins.isAttrs v) || skipKey name then
        acc
      else
        acc // (lib.optionalAttrs (v ? crds) { ${name} = v; }) // (collectAspectsWithCrds v)
    ) { } node;
  aspectsWithCrds = collectAspectsWithCrds aspects;

  # Forward only the present, non-empty keys of a subset — so unset optional
  # CRD config (namePrefix, etc.) isn't passed through to the nixidy accessors.
  pickNonEmpty =
    keys: attrs:
    lib.filterAttrs (_: v: v != null && v != "" && v != { }) (
      builtins.intersectAttrs (lib.genAttrs keys (_: null)) attrs
    );

  # Build one aspect's CRDs into { module; objects } via nixidy's value
  # accessors. Pure dispatch on whether the aspect ships a chart or a src tree:
  #   - chart: template against THIS host's Kubernetes version; the module and
  #            object accessors share that one (memoized) helm run.
  #   - src:   read the CRD YAML files directly.
  # Objects deploy every CRD found; only the generated types are narrowed to
  # the aspect's `crds` kinds.
  mkCrd =
    { pkgs, system }:
    let
      generators = inputs.nixidy.packages.${system}.generators;
      kubeVersion = "v${pkgs.kubernetes.version}";

      # Optional type-generation tuning, forwarded only when the aspect sets it.
      typeOpts = pickNonEmpty [
        "namePrefix"
        "attrNameOverrides"
        "skipCoerceToList"
      ];

      # Chart aspect → { module; objects }. Both accessors share `chartArgs`, so
      # the chart is templated once (memoized). Objects deploy every CRD; only
      # the generated types are narrowed to the aspect's `crds` kinds.
      fromChart =
        name: cfg:
        let
          chartArgs = {
            inherit name kubeVersion;
          }
          // pickNonEmpty [ "chart" "chartAttrs" "values" "extraOpts" ] cfg;
        in
        {
          module = generators.fromChartCRDModule (chartArgs // { crds = cfg.crds or [ ]; } // typeOpts cfg);
          objects = generators.crdObjectsFromChart chartArgs;
        };

      # Src aspect → { module; objects }. `crds` is the list of CRD YAML files.
      fromSrc = name: cfg: {
        module = generators.fromCRDModule (
          {
            inherit name;
            inherit (cfg) src crds;
          }
          // typeOpts cfg
        );
        objects = generators.crdObjects { inherit (cfg) src crds; };
      };
    in
    name: aspect:
    let
      cfg = aspect.crds {
        inherit
          pkgs
          lib
          inputs
          system
          ;
      };
    in
    if cfg.chart or null != null || cfg.chartAttrs or { } != { } then
      fromChart name cfg
    else if cfg.src or null != null then
      fromSrc name cfg
    else
      throw "den: aspect '${name}' has CRDs defined but neither 'src' nor 'chart'/'chartAttrs' are set";

  # ===========================================================================
  # Cluster modules
  #
  # The per-cluster nixidy modules: which hosts belong to the cluster, the SOPS
  # encryption config, and nixidy's own defaults (target, sync policy, …).
  # ===========================================================================

  # Hosts belonging to a cluster. Mirrors the policy in clusters.nix but at the
  # flake level for nixidy extraSpecialArgs. The nixidy modules only use hosts
  # for network topology lookups, so environment membership is sufficient here;
  # role-based filtering happens at the den policy level.
  resolveClusterHosts =
    cluster:
    let
      nixosConfigs = config.flake.nixosConfigurations or { };
    in
    if cluster.hosts != null then
      lib.filterAttrs (name: _: lib.elem name cluster.hosts) nixosConfigs
    else
      nixosConfigs;

  # SOPS encryption module for a cluster.
  mkAgeModule =
    { cluster, environment }:
    _: {
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

  # nixidy's own configuration for a cluster: env name, the CRD type modules,
  # target repo/branch/path, and rendering defaults.
  mkNixidyModule =
    { envName, crdModules }:
    { lib, ... }:
    {
      nixidy = {
        env = lib.mkDefault envName;
        applicationImports = crdModules;

        target = {
          repository = lib.mkDefault "https://github.com/${repo.owner}/${repo.name}.git";
          branch = lib.mkDefault "main";
          rootPath = lib.mkDefault "./generated/manifests/${envName}";
        };

        bootstrapManifest.enable = true;

        extraFiles."README.md".text = ''
          # Rendered manifests

          The manifests in this directory are generated by [nixidy](https://github.com/arnarg/nixidy).
        '';

        defaults = {
          syncPolicy.autoSync = {
            enable = true;
            prune = true;
            selfHeal = true;
          };

          # Strip release-tracking labels that produce noisy diffs
          helm.transformer = map (
            lib.kube.removeLabels [
              "app.kubernetes.io/managed-by"
              "app.kubernetes.io/version"
              "helm.sh/chart"
            ]
          );
        };
      };
    };

  # ===========================================================================
  # Environment
  #
  # Assemble a complete nixidy environment for one cluster: collect its CRDs,
  # wire den-collected kubernetes modules, sops, and nixidy config together.
  # ===========================================================================
  mkEnv =
    {
      system,
      pkgs,
      clusterName,
      cluster,
    }:
    let
      envName = "${cluster.environment}-${clusterName}";
      environment = environments.${cluster.environment};

      # Per-aspect CRDs → { module; objects }. module → applicationImports
      # (resource types); objects → bootstrap (raw CRD manifests to deploy).
      crds = lib.mapAttrs (mkCrd { inherit pkgs system; }) aspectsWithCrds;
    in
    inputs.nixidy.lib.mkEnv {
      inherit pkgs;
      charts =
        (inputs.nixhelm.chartsDerivations.${system} or { })
        // (config.flake.chartsDerivations.${system} or { });

      extraSpecialArgs = {
        inherit environment cluster inputs;
        hosts = resolveClusterHosts cluster;
      };

      modules = [
        inputs.agenix-rekey-to-sops.sopsModules.default
        # Custom agenix-rekey generator types (standalone NixOS module)
        (import ../aspects/secrets/_generators-module.nix)
        (mkAgeModule {
          inherit environment;
          cluster = cluster // {
            name = clusterName;
          };
        })
        (mkNixidyModule {
          inherit envName;
          crdModules = lib.mapAttrsToList (_: c: c.module) crds;
        })
        # Raw CRD manifests for the bootstrap app to deploy — set here, where
        # the CRDs are computed; the bootstrap aspect owns the rest of that app.
        { applications.bootstrap.objects = lib.concatMap (c: c.objects) (lib.attrValues crds); }
      ]
      # den-collected kubernetes-class modules for this cluster
      ++ (config.flake.nixidyModules.${clusterName} or [ ]);
    };
in
{
  # A nixidy environment per cluster, keyed "<environment>-<cluster>".
  flake.nixidyEnvs = lib.genAttrs config.systems (
    system:
    withSystem system (
      { pkgs, ... }:
      lib.mapAttrs' (clusterName: cluster: {
        name = "${cluster.environment}-${clusterName}";
        value = mkEnv {
          inherit
            system
            pkgs
            clusterName
            cluster
            ;
        };
      }) clusters
    )
  );

  # nixidy-all-envs: every env's manifests linked together with a manifest.json
  # index. Defined at flake level (not perSystem) because it reads the den
  # pipeline output config.flake.nixidyEnvs, which perSystem cannot reach
  # without a circular dependency.
  flake.packages = lib.genAttrs config.systems (
    system:
    withSystem system (
      { pkgs, ... }:
      let
        envData = lib.mapAttrs (_env: nixidyEnv: {
          inherit (nixidyEnv.config.nixidy.target) repository branch rootPath;
          package = nixidyEnv.environmentPackage;
        }) (config.flake.nixidyEnvs.${system} or { });
      in
      {
        nixidy-all-envs = pkgs.runCommand "nixidy-all-envs" { } ''
          mkdir -p $out
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (env: data: "ln -s ${data.package} $out/${env}") envData
          )}
          cat > $out/manifest.json <<'MANIFEST'
          ${builtins.toJSON (
            lib.mapAttrs (_env: data: {
              inherit (data) repository branch rootPath;
              packagePath = "${data.package}";
            }) envData
          )}
          MANIFEST
        '';
      }
    )
  );

  perSystem =
    { config, ... }:
    {
      # CRDs (type modules + objects) are built as values directly in mkEnv via
      # nixidy's accessors, so there are no perSystem CRD packages.
      pre-commit.settings.hooks.k8s-update-manifests = {
        enable = true;
        name = "k8s-update-manifests";
        description = "Run k8s-update-manifests to re-generate argocd config";
        entry = "${config.packages.k8s-update-manifests}/bin/k8s-update-manifests --skip-secrets";
        files = "^(flake\\.lock|modules/(den/clusters|den/aspects/kubernetes|den/kubernetes)/.*\\.nix)$";
        pass_filenames = false;
      };
    };
}
