# Nixidy assembly module — bridges den-collected kubernetes modules,
# CRD build pipeline, and nixidy environment generation.
#
# Replaces legacy:
#   modules/flake-parts/kubernetes/nixidy-helpers.nix
#   modules/flake-parts/kubernetes/nixidy-envs.nix
#   modules/flake-parts/kubernetes/service-helpers.nix
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

  # The kubernetes aspect tree is nested (services/network/cilium, etc.), and a
  # node may be both an aspect (with crds) AND a parent of child aspects
  # (e.g. cilium parents hubble-ui + cilium-bgp-resources). Recurse the tree —
  # skipping structural/class/quirk keys — and collect every node that declares
  # a `crds` function, keyed by its leaf name. (Mirrors host.nix's nodeModule.)
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

  # Aspects that declare a crds function (flattened from the nested tree)
  aspectsWithCrds = collectAspectsWithCrds aspects;

  # Given a subset of keys from an attrset, return only those that are
  # present and whose values are non-empty. Used to forward optional
  # CRD configuration without passing unset keys.
  pickNonEmpty =
    keys: attrs:
    lib.filterAttrs (_: v: v != null && v != "" && v != { }) (
      builtins.intersectAttrs (lib.genAttrs keys (_: null)) attrs
    );

  # Resolve hosts belonging to a cluster by matching environment + role
  # against nixosConfigurations. Mirrors the policy in clusters.nix but
  # operates at the flake level for nixidy extraSpecialArgs.
  resolveClusterHosts =
    cluster:
    let
      nixosConfigs = config.flake.nixosConfigurations or { };
    in
    if cluster.hosts != null then
      lib.filterAttrs (name: _: lib.elem name cluster.hosts) nixosConfigs
    else
      lib.filterAttrs (
        _name: _:
        # Host belongs to cluster if it's in the same environment.
        # Role-based filtering happens at the den policy level;
        # here we pass all environment hosts since the nixidy modules
        # only use hosts for network topology lookups.
        true
      ) nixosConfigs;

  # SOPS encryption module for a nixidy cluster.
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

  # CRD objects pre-parsed at build time, read back at eval time to avoid IFD.
  getServiceCrdObjects =
    { system, enabledAspects }:
    let
      parsedCrdObjects = withSystem system ({ config, ... }: config.packages.parsed-crd-objects);
      availableFiles = builtins.readDir parsedCrdObjects;
    in
    lib.mapAttrs (
      name: _:
      let
        jsonFile = "${name}.json";
      in
      if availableFiles ? ${jsonFile} then
        builtins.fromJSON (builtins.readFile (parsedCrdObjects + "/${jsonFile}"))
      else
        [ ]
    ) enabledAspects;

  # Generated CRD type definitions as nixidy applicationImports.
  getCrdApplicationImports =
    { system, enabledAspects }:
    let
      generatedCrds = withSystem system ({ config, ... }: config.packages.generated-crds);
      dirContents = builtins.readDir generatedCrds;
      allNixFiles = lib.attrNames (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) dirContents
      );
      enabledNames = builtins.attrNames enabledAspects;
      enabledNixFiles = lib.filter (
        name: lib.elem (lib.removeSuffix ".nix" name) enabledNames
      ) allNixFiles;
    in
    map (name: import (generatedCrds + "/${name}")) enabledNixFiles;

  # Core nixidy configuration module for a cluster.
  mkNixidyModule =
    {
      envName,
      enabledAspects,
      system,
      cluster,
    }:
    { lib, ... }:
    {
      config = {
        nixidy = {
          env = lib.mkDefault envName;
          applicationImports = getCrdApplicationImports { inherit system enabledAspects; };

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
              enabled = true;
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
    };

  # Assemble a complete nixidy environment for a cluster.
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
      hosts = resolveClusterHosts cluster;

      # Aspects included in this cluster via den — the battery collects
      # kubernetes-class modules into nixidyModules.<clusterName>
      denModules = config.flake.nixidyModules.${clusterName} or [ ];

      # Aspects with CRDs that are relevant to this cluster
      enabledAspects = aspectsWithCrds;

      serviceCrdObjects = getServiceCrdObjects { inherit system enabledAspects; };
      userCharts = config.flake.chartsDerivations.${system} or { };

      # Custom agenix-rekey generator types (standalone NixOS module)
      agenixGeneratorsModule = import ../aspects/secrets/_generators-module.nix;
    in
    inputs.nixidy.lib.mkEnv {
      inherit pkgs;
      charts = (inputs.nixhelm.chartsDerivations.${system} or { }) // userCharts;
      extraSpecialArgs = {
        inherit
          environment
          cluster
          inputs
          hosts
          ;
        crdObjects = serviceCrdObjects;
      };
      modules = [
        inputs.agenix-rekey-to-sops.sopsModules.default
        agenixGeneratorsModule
        (mkAgeModule {
          inherit environment;
          cluster = cluster // {
            name = clusterName;
          };
        })
        (mkNixidyModule {
          inherit
            envName
            system
            enabledAspects
            ;
          cluster = cluster // {
            name = clusterName;
          };
        })
      ]
      ++ denModules;
    };

  # Build helpers for CRD packages, scoped to a system's pkgs.
  mkPerSystemHelpers =
    {
      pkgs,
      system,
    }:
    let
      klib = inputs.nix-kube-generators.lib { inherit pkgs; };

      # Evaluate each aspect's CRD function with perSystem args
      callAspectCrds =
        aspect:
        aspect.crds {
          inherit
            pkgs
            lib
            inputs
            system
            ;
        };

      resolveChart =
        crdConfig:
        if crdConfig.chart or null != null then
          crdConfig.chart
        else
          klib.downloadHelmChart crdConfig.chartAttrs;

      # Shared derivation: helm template once per chart-based aspect
      mkChartCrdYaml =
        name: crdConfig:
        pkgs.stdenv.mkDerivation {
          name = "chart-crds-${name}";
          passAsFile = [ "helmValues" ];
          helmValues = builtins.toJSON (crdConfig.values or { });

          allowSubstitutes = false;
          preferLocalBuild = true;

          phases = [ "installPhase" ];
          installPhase = ''
            export HELM_CACHE_HOME="$TMP/.nix-helm-build-cache"
            mkdir -p $out

            ${pkgs.kubernetes-helm}/bin/helm template \
            --include-crds \
            --kube-version "v${pkgs.kubernetes.version}" \
            --values "$helmValuesPath" \
            "${name}" \
            "${resolveChart crdConfig}" \
            ${builtins.concatStringsSep " " (crdConfig.extraOpts or [ ])} \
            > $out/crds.yaml
          '';
        };

      # Pre-compute chart CRD YAML for reuse
      chartCrdYamls =
        lib.mapAttrs
          (
            name: aspect:
            let
              crdConfig = callAspectCrds aspect;
            in
            mkChartCrdYaml name crdConfig
          )
          (
            lib.filterAttrs (
              _: aspect:
              let
                c = callAspectCrds aspect;
              in
              c.chart or null != null || c.chartAttrs or { } != { }
            ) aspectsWithCrds
          );
    in
    {
      # Parse CRD objects to JSON for eval-time consumption
      mkParsedServiceCrds =
        name: aspect:
        let
          crdConfig = callAspectCrds aspect;
          useChart = crdConfig.chart or null != null || crdConfig.chartAttrs or { } != { };
        in
        if useChart then
          pkgs.runCommand "parse-${name}-crds"
            {
              nativeBuildInputs = [
                pkgs.yq
                pkgs.jq
              ];
              src = chartCrdYamls.${name};
              allowSubstitutes = false;
              preferLocalBuild = true;
            }
            ''
              ${pkgs.yq}/bin/yq -Ms '.' "$src/crds.yaml" \
              | ${pkgs.jq}/bin/jq '[.[] | select(. != null and .kind == "CustomResourceDefinition")]' \
              > $out
            ''
        else
          pkgs.runCommand "parse-${name}-crds"
            {
              nativeBuildInputs = [
                pkgs.yq
                pkgs.jq
              ];
              inherit (crdConfig) src;
              crds = builtins.toJSON crdConfig.crds;
              allowSubstitutes = false;
              preferLocalBuild = true;
            }
            ''
              tempFiles=()
              i=0
              for crd in $(echo "$crds" | ${pkgs.jq}/bin/jq -r '.[]'); do
                tempFile="temp_$i.json"
                ${pkgs.yq}/bin/yq -Ms '.' "$src/$crd" | \
                  jq '[.[] | select(type == "object" and .kind == "CustomResourceDefinition")]' > "$tempFile"
                tempFiles+=("$tempFile")
                i=$((i + 1))
              done
              ${pkgs.jq}/bin/jq -s 'add' "''${tempFiles[@]}" > $out
            '';

      # Generate nixidy CRD type .nix files
      mkCrdGenerator =
        { fromCRD }:
        name: aspect:
        let
          crdConfig = callAspectCrds aspect;
          useChart = crdConfig.chart or null != null || crdConfig.chartAttrs or { } != { };
          useSrc = crdConfig.src or null != null;
        in
        if useChart then
          fromCRD (
            {
              inherit name;
              src = chartCrdYamls.${name};
              crds = [ "crds.yaml" ];
              kindFilter = crdConfig.crds or [ ];
            }
            // pickNonEmpty [ "namePrefix" "attrNameOverrides" "skipCoerceToList" ] crdConfig
          )
        else if useSrc then
          fromCRD (
            {
              inherit name;
              inherit (crdConfig) src crds;
            }
            // pickNonEmpty [ "namePrefix" "attrNameOverrides" "skipCoerceToList" ] crdConfig
          )
        else
          throw "den: aspect '${name}' has CRDs defined but neither 'src' nor 'chart'/'chartAttrs' are set";
    };
in
{
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

  # nixidy-all-envs at flake level — perSystem cannot access config.flake
  # den pipeline outputs (nixidyModules) without circular dependency.
  flake.packages = lib.genAttrs config.systems (
    system:
    withSystem system (
      { pkgs, ... }:
      let
        envs = config.flake.nixidyEnvs.${system} or { };
        envData = lib.mapAttrs (
          _env: nixidyEnv:
          let
            target = nixidyEnv.config.nixidy.target;
          in
          {
            inherit (target) repository branch rootPath;
            package = nixidyEnv.environmentPackage;
          }
        ) envs;
        envNames = lib.attrNames envData;
      in
      {
        nixidy-all-envs = pkgs.runCommand "nixidy-all-envs" { } ''
          mkdir -p $out
          ${lib.concatMapStringsSep "\n" (
            env:
            let
              data = envData.${env};
            in
            ''
              ln -s ${data.package} $out/${env}
            ''
          ) envNames}
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
    {
      config,
      inputs',
      pkgs,
      system,
      ...
    }:
    let
      helpers = mkPerSystemHelpers { inherit pkgs system; };
      inherit (helpers) mkParsedServiceCrds mkCrdGenerator;
    in
    {
      packages = {
        parsed-crd-objects =
          let
            parsedServices = lib.mapAttrs mkParsedServiceCrds aspectsWithCrds;
            serviceNames = lib.attrNames parsedServices;
            serviceDrvs = lib.attrValues parsedServices;
          in
          pkgs.runCommand "parsed-crd-objects" { } ''
            # Force all derivations into scope for parallel dependency discovery
            : ${toString serviceDrvs}

            mkdir -p $out
            ${lib.concatMapStringsSep "\n" (name: ''
              cp ${parsedServices.${name}} $out/${name}.json
            '') serviceNames}
          '';

        generated-crds =
          let
            generators = lib.mapAttrs (mkCrdGenerator {
              inherit (inputs'.nixidy.packages.generators) fromCRD;
            }) aspectsWithCrds;
            generatorNames = lib.attrNames generators;
            generatorDrvs = lib.attrValues generators;
          in
          pkgs.runCommand "generated-crds" { } ''
            # Force all derivations into scope for parallel dependency discovery
            : ${toString generatorDrvs}

            mkdir -p $out
            ${lib.concatMapStringsSep "\n" (name: ''
              cp ${generators.${name}} $out/${name}.nix
            '') generatorNames}
          '';

        # nixidy-all-envs is defined at flake level (flake.packages) to avoid
        # circular dependency — perSystem cannot access config.flake den
        # pipeline outputs (nixidyModules).
      };

      pre-commit.settings.hooks.k8s-update-manifests = {
        enable = true;
        name = "k8s-update-manifests";
        description = "Run k8s-update-manifests to re-generate argocd config";
        entry = "${config.packages.k8s-update-manifests}/bin/k8s-update-manifests --skip-secrets";
        files = "^(flake\\.lock|modules/(den/clusters|den/aspects/kubernetes|den/kubernetes)/.*\\.nix)$";
        pass_filenames = false;
      };
    };

  # Kubernetes devshell commands emitted via class routing
  den.aspects.devshell.kubernetes = {
    devshell =
      { self', inputs', ... }:
      {
        commands = [
          {
            package = self'.packages.k8s-update-manifests;
            name = "k8s-update-manifests";
            help = "Update Kubernetes manifests for nixidy environments";
          }
          {
            package = self'.packages.toggle-axon-kubernetes;
            name = "toggle-axon-kubernetes";
            help = "Toggle enable/disable Kubernetes on axon cluster nodes";
          }
          {
            package = self'.packages.convert-oidc-secrets;
            name = "convert-oidc-secrets";
            help = "Convert age-encrypted OIDC secrets to SOPS-encrypted YAML format";
          }
          {
            name = "helmupdater";
            command = ''${inputs'.nixhelm.packages.helmupdater}/bin/helmupdater "$@"'';
            help = "Update helm chart versions and hashes";
          }
          {
            package = self'.packages.oci-image-updater;
            name = "oci-image-updater";
            help = "Update OCI container image versions and hashes";
          }
        ];
      };
  };
  den.schema.flake-parts.includes = [ den.aspects.devshell.kubernetes ];
}
