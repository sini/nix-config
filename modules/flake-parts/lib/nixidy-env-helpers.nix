{
  config,
  inputs,
  withSystem,
  lib,
  ...
}:
{
  flake.lib.nixidy-env-helpers =
    let
      inherit (config.flake.meta) repo;
      inherit (config.flake.lib.kubernetes-services) nixidyKubernetesType;

      # Core infrastructure services required by every nixidy environment.
      # These are always included regardless of per-environment configuration.
      defaultServices = [
        "bootstrap"
        "argocd"
        "cert-manager"
        "cilium"
        "envoy-gateway"
        "sops-secrets-operator"
      ];

      # Given a subset of keys from `crdConfig`, return only those that are
      # present and whose values are non-empty (non-null, non-"", non-{}).
      # Used to forward optional CRD configuration without passing unset keys.
      pickNonEmpty =
        keys: attrs:
        lib.filterAttrs (_: v: v != null && v != "" && v != { }) (
          builtins.intersectAttrs (lib.genAttrs keys (_: null)) attrs
        );

      # Merge defaultServices with any additional services enabled in an
      # environment's kubernetes.services.enabled list.
      # environment -> [string]
      getEnabledServices =
        environment: lib.unique (defaultServices ++ (environment.kubernetes.services.enabled or [ ]));

      # Resolve enabled service names to their nixidy module definitions.
      # Filters out service names that aren't defined in kubernetes.services
      # (e.g. services enabled by the environment but not yet implemented).
      # [string] -> [module]
      getServiceModules =
        enabledServices:
        lib.map (serviceName: config.kubernetes.services.${serviceName}.nixidy) (
          lib.filter (serviceName: config.kubernetes.services ? ${serviceName}) enabledServices
        );

      # Resolve CRD objects for each enabled service at evaluation time.
      # All CRD objects (both source-based and chart-based) are pre-parsed into
      # JSON at build time by the parsed-crd-objects package, then read back here.
      # This avoids expensive IFD (helm template + YAML parsing) during evaluation.
      # { system, enabledServices } -> { serviceName -> [crdObject] }
      getServiceCrdObjects =
        {
          system,
          enabledServices,
        }:
        let
          parsedCrdObjects = withSystem system ({ config, ... }: config.packages.parsed-crd-objects);
          # Use builtins.readDir to discover available files.
          availableFiles = builtins.readDir parsedCrdObjects;
        in
        lib.mapAttrs (
          name: service:
          if service.crds == null then
            [ ]
          else
            let
              jsonFile = "${name}.json";
            in
            if availableFiles ? ${jsonFile} then
              builtins.fromJSON (builtins.readFile (parsedCrdObjects + "/${jsonFile}"))
            else
              [ ]
        ) (lib.filterAttrs (name: _: lib.elem name enabledServices) config.kubernetes.services);

      # Produce the agenix-rekey-to-sops configuration module for a nixidy environment.
      # Configures SOPS encryption paths and rekey identity based on environment.
      # environmentConfig -> module
      mkAgeModule =
        environment:
        { inputs, ... }:
        {
          age = {
            sops = {
              outputDir = environment.secretPath + "/sops";
            };
            rekey = {
              recipientIdentifier = environment.name;
              storageMode = "local";
              generatedSecretsDir = environment.secretPath + "/generated";
              localStorageDir = environment.secretPath + "/rekeyed";
              inherit (inputs.self.secretsConfig) masterIdentities;
            };
          };
        };

      # Import generated CRD type definitions as nixidy applicationImports, filtered
      # to only include services that are enabled in this environment.
      # Reads .nix files from the generated-crds perSystem package derivation.
      # { system, enabledServices } -> [module]
      getCrdApplicationImports =
        { system, enabledServices }:
        let
          generatedCrds = withSystem system ({ config, ... }: config.packages.generated-crds);
          # Read directory and filter for .nix files
          dirContents = builtins.readDir generatedCrds;
          allNixFiles = lib.attrNames (
            lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) dirContents
          );
          enabledNixFiles = lib.filter (
            name: lib.elem (lib.removeSuffix ".nix" name) enabledServices
          ) allNixFiles;
        in
        map (name: import (generatedCrds + "/${name}")) enabledNixFiles;

      # Build the core nixidy configuration module for an environment.
      # This sets up:
      # - The kubernetes option type (flattened service access for nixidy modules)
      # - Environment kubernetes config injection as mkDefault values
      # - CRD application imports for enabled services
      # - Git target repository and branch for rendered manifests
      # - ArgoCD sync policy and helm label stripping defaults
      # { env, environment, enabledServices, system } -> module
      mkNixidyModule =
        {
          env,
          environment,
          enabledServices,
          system,
        }:
        { lib, ... }:
        {
          options.kubernetes = lib.mkOption {
            type = nixidyKubernetesType;
            default = { };
            description = "Kubernetes configuration for this nixidy environment";
          };

          config = {
            # Inject environment-level kubernetes values as defaults.
            # Services are flattened from the split enabled/config structure
            # into direct service access for nixidy modules.
            kubernetes = lib.mapAttrs (
              name: value:
              if name == "services" then
                lib.mapAttrs (_: lib.mkDefault) environment.kubernetes.services.config
              else
                lib.mkDefault value
            ) environment.kubernetes;

            nixidy = {
              env = lib.mkDefault env;
              applicationImports = getCrdApplicationImports { inherit system enabledServices; };

              target = {
                repository = lib.mkDefault "https://github.com/${repo.owner}/${repo.name}.git";
                branch = lib.mkDefault "main";
                rootPath = lib.mkDefault "./generated/manifests/${env}";
              };

              bootstrapManifest.enable = true;

              extraFiles."README.md".text = ''
                # Rendered manifests

                The manifests in this directory are generated by [nixidy](https://github.com/arnarg/nixidy).
              '';

              defaults = {
                syncPolicy = {
                  autoSync = {
                    enabled = true;
                    prune = true;
                    selfHeal = true;
                  };
                };

                # Many helm charts render resources with release-tracking labels
                # (managed-by, version, helm.sh/chart) whose values change every
                # release. This produces large, noisy diffs in the rendered manifests.
                # Strip them after templating to keep diffs meaningful.
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

      # Assemble a complete nixidy environment from its constituent parts.
      # This is the primary entry point — it resolves enabled services,
      # collects their modules and CRD objects, merges helm charts, and
      # produces a full nixidy environment via inputs.nixidy.lib.mkEnv.
      # { system, pkgs, env, environment } -> nixidyEnv
      mkEnv =
        {
          system,
          pkgs,
          env,
          environment,
        }:
        let
          enabledServices = getEnabledServices environment;
          serviceModules = getServiceModules enabledServices;
          serviceCrdObjects = getServiceCrdObjects { inherit system enabledServices; };
          userCharts = config.flake.chartsDerivations.${system} or { };
        in
        inputs.nixidy.lib.mkEnv {
          inherit pkgs;
          charts = (inputs.nixhelm.chartsDerivations.${system} or { }) // userCharts;
          extraSpecialArgs = {
            inherit environment inputs;
            inherit (config.flake) hosts;
            crdObjects = serviceCrdObjects;
          };
          modules = [
            # Include agenix-rekey-to-sops module
            inputs.agenix-rekey-to-sops.sopsModules.default

            # This local feature system module is also compatible with nixidy envs
            # It provides our custom agenix generator types
            config.features.agenix-generators.system

            (mkAgeModule environment)
            (mkNixidyModule {
              inherit
                env
                environment
                enabledServices
                system
                ;
            })
          ]
          ++ serviceModules;
        };

      # Build helpers scoped to a specific system's packages and perSystem config.
      # These are used by the perSystem section of nixidy-envs.nix to build the
      # parsed-crd-objects and generated-crds packages.
      # { pkgs, sharedConfig } -> { servicesWithCrds, mkParsedServiceCrds, mkCrdGenerator }
      mkPerSystemHelpers =
        { pkgs, sharedConfig }:
        let
          # Evaluate a service's CRD function with perSystem module args.
          callServiceCrds = service: service.crds (sharedConfig // { inherit inputs; });

          klib = inputs.nix-kube-generators.lib { inherit pkgs; };

          # All services that define CRDs (either source-based or chart-based)
          servicesWithCrds = lib.filterAttrs (
            _name: service: service.crds != null
          ) config.kubernetes.services;

          # Resolve chart derivation from crdConfig. Shared between
          # mkChartCrdYaml, mkParsedServiceCrds, and mkCrdGenerator.
          resolveChart =
            crdConfig:
            if crdConfig.chart or null != null then
              crdConfig.chart
            else
              klib.downloadHelmChart crdConfig.chartAttrs;

          # Shared derivation: run helm template once per chart-based service.
          # Both mkParsedServiceCrds and mkCrdGenerator (via fromCRD) consume
          # this output, avoiding duplicate helm template builds.
          mkChartCrdYaml =
            name: crdConfig:
            pkgs.stdenv.mkDerivation {
              name = "chart-crds-${name}";
              passAsFile = [ "helmValues" ];
              helmValues = builtins.toJSON (crdConfig.values or { });

              # Don't check remote stores for this local IFD derivation
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

          # Pre-compute chart CRD YAML derivations for all chart-based services.
          # This ensures the same derivation is reused by both mkParsedServiceCrds
          # and mkCrdGenerator.
          chartCrdYamls =
            lib.mapAttrs
              (
                name: service:
                let
                  crdConfig = callServiceCrds service;
                in
                mkChartCrdYaml name crdConfig
              )
              (
                lib.filterAttrs (
                  _: service:
                  let
                    c = callServiceCrds service;
                  in
                  c.chart or null != null || c.chartAttrs or { } != { }
                ) servicesWithCrds
              );
        in
        {
          inherit servicesWithCrds;

          # Build a derivation that extracts CRD objects as JSON for a service.
          # For chart-based services, consumes the shared mkChartCrdYaml output.
          # The resulting JSON is read at eval time by getServiceCrdObjects.
          # string -> service -> derivation
          mkParsedServiceCrds =
            name: service:
            let
              crdConfig = callServiceCrds service;
              useChart = crdConfig.chart or null != null || crdConfig.chartAttrs or { } != { };
            in
            if useChart then
              # Chart-based: read shared helm template output → extract CRDs → JSON
              pkgs.runCommand "parse-${name}-crds"
                {
                  nativeBuildInputs = [
                    pkgs.yq
                    pkgs.jq
                  ];
                  src = chartCrdYamls.${name};

                  # Don't check remote stores for this local IFD derivation
                  allowSubstitutes = false;
                  preferLocalBuild = true;
                }
                ''
                  ${pkgs.yq}/bin/yq -Ms '.' "$src/crds.yaml" \
                  | ${pkgs.jq}/bin/jq '[.[] | select(. != null and .kind == "CustomResourceDefinition")]' \
                  > $out
                ''
            else
              # Source-based: parse YAML files → extract CRDs → JSON array
              pkgs.runCommand "parse-${name}-crds"
                {
                  nativeBuildInputs = [
                    pkgs.yq
                    pkgs.jq
                  ];
                  inherit (crdConfig) src;
                  crds = builtins.toJSON crdConfig.crds;

                  # Don't check remote stores for this local IFD derivation
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

          # Build a nixidy CRD type generator derivation for a service.
          # For chart-based services, reuses the shared mkChartCrdYaml derivation
          # as the src for fromCRD, so helm template runs only once per service.
          # { fromCRD, fromChartCRD } -> string -> service -> derivation
          mkCrdGenerator =
            { fromCRD }:
            name: service:
            let
              crdConfig = callServiceCrds service;
              useChart = crdConfig.chart or null != null || crdConfig.chartAttrs or { } != { };
              useSrc = crdConfig.src or null != null;
            in
            if useChart then
              # Use fromCRD with the shared chart-crds derivation as src,
              # instead of fromChartCRD which would run helm template again.
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
              throw "Service '${name}' has CRDs defined but neither 'src' nor 'chart'/'chartAttrs' are set";
        };
    in
    {
      inherit mkEnv mkPerSystemHelpers;
    };
}
