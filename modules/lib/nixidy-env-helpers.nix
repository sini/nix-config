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
      inherit (config.flake.lib.kubernetes-utils) extractCRDsFromChart;
      inherit (config.flake.secretsPaths) rawSecretsPath rawSopsConfigPath;

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
      # Filters out service names that aren't defined in flake.kubernetes.services
      # (e.g. services enabled by the environment but not yet implemented).
      # [string] -> [module]
      getServiceModules =
        enabledServices:
        lib.map (serviceName: config.flake.kubernetes.services.${serviceName}.nixidy) (
          lib.filter (serviceName: config.flake.kubernetes.services ? ${serviceName}) enabledServices
        );

      # Resolve CRD objects for each enabled service at evaluation time.
      # For source-based CRDs, reads from pre-parsed JSON build artifacts (see
      # parsed-crd-objects package in perSystem) to avoid expensive YAML parsing
      # during Nix evaluation. For chart-based CRDs, delegates to extractCRDsFromChart.
      #
      # Note: this evaluates service.crds with flake-level args ({ pkgs, lib, system, inputs }),
      # which differs from the perSystem callServiceCrds that passes sharedConfig.
      # Both produce the same crdConfig; the arg shapes differ because flake-level
      # code doesn't have access to the perSystem module args pattern.
      # { system, pkgs, enabledServices } -> { serviceName -> [crdObject] }
      getServiceCrdObjects =
        {
          system,
          pkgs,
          enabledServices,
        }:
        let
          parsedCrdObjects = withSystem system ({ config, ... }: config.packages.parsed-crd-objects);
        in
        lib.mapAttrs (
          name: service:
          let
            crdConfig =
              if service.crds != null then
                service.crds {
                  inherit pkgs lib system;
                  inherit (inputs) inputs';
                  inherit inputs;
                }
              else
                null;
          in
          if crdConfig == null then
            [ ]
          else if (crdConfig.src or null != null) then
            # Source-based CRDs: use pre-parsed JSON from build-time derivation
            let
              parsedFile = parsedCrdObjects + "/${name}.json";
            in
            if builtins.pathExists parsedFile then builtins.fromJSON (builtins.readFile parsedFile) else [ ]
          else
            # Chart-based CRDs: extract at eval time via nix-kube-generators
            let
              klib = inputs.nix-kube-generators.lib { inherit pkgs; };
              # Filter out generator-only options (namePrefix, attrNameOverrides, skipCoerceToList)
              # that extractCRDsFromChart doesn't accept
              extractConfig = builtins.intersectAttrs {
                chart = null;
                chartAttrs = null;
                values = null;
                crds = null;
                extraOpts = null;
              } crdConfig;
            in
            extractCRDsFromChart (extractConfig // { inherit name klib; })
        ) (lib.filterAttrs (name: _: lib.elem name enabledServices) config.flake.kubernetes.services);

      # Produce the agenix-rekey-to-sops configuration module for a nixidy environment.
      # Configures SOPS encryption paths and rekey identity based on environment name.
      # string -> module
      mkAgeModule =
        env:
        { inputs, ... }:
        {
          age = {
            sops = {
              configFile = rawSopsConfigPath;
              outputDir = rawSecretsPath + "/env/${env}/sops";
            };
            rekey = {
              recipientIdentifier = env;
              storageMode = "local";
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
          allNixFiles = lib.attrNames (
            lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (
              builtins.readDir generatedCrds
            )
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
          serviceCrdObjects = getServiceCrdObjects { inherit system pkgs enabledServices; };
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
            inputs.agenix-rekey-to-sops.sopsModules.default
            (mkAgeModule env)
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
      # { pkgs, sharedConfig } -> { servicesWithSrcCrds, servicesWithCrds, mkParsedServiceCrds, mkCrdGenerator }
      mkPerSystemHelpers =
        { pkgs, sharedConfig }:
        let
          # Evaluate a service's CRD function with perSystem module args.
          # This is the perSystem equivalent of the inline service.crds call in
          # getServiceCrdObjects — same result, different arg shape (perSystem
          # module args pattern vs explicit { pkgs, lib, system, inputs }).
          callServiceCrds = service: service.crds (sharedConfig // { inherit inputs; });

          # All services that define CRDs (either source-based or chart-based)
          servicesWithCrds = lib.filterAttrs (
            _name: service: service.crds != null
          ) config.flake.kubernetes.services;
        in
        {
          inherit servicesWithCrds;

          # Subset of servicesWithCrds that use source-based CRDs (YAML files
          # that need to be parsed into JSON at build time for eval-time caching)
          servicesWithSrcCrds = lib.filterAttrs (
            _name: service: (callServiceCrds service).src or null != null
          ) servicesWithCrds;

          # Build a derivation that converts a service's CRD YAML files into a
          # single JSON array of CustomResourceDefinition objects. These are read
          # at eval time by getServiceCrdObjects to avoid slow YAML parsing.
          # string -> service -> derivation
          mkParsedServiceCrds =
            name: service:
            let
              crdConfig = callServiceCrds service;
            in
            pkgs.runCommand "parse-${name}-crds"
              {
                nativeBuildInputs = [
                  pkgs.yq-go
                  pkgs.jq
                ];
                inherit (crdConfig) src;
                crds = builtins.toJSON crdConfig.crds;
              }
              ''
                # Parse each CRD YAML file and extract CustomResourceDefinition objects
                tempFiles=()
                i=0
                for crd in $(echo "$crds" | jq -r '.[]'); do
                  tempFile="temp_$i.json"
                  yq eval -o=json '.' "$src/$crd" | \
                    jq -s 'map(select(type == "object" and .kind == "CustomResourceDefinition"))' > "$tempFile"
                  tempFiles+=("$tempFile")
                  i=$((i + 1))
                done
                jq -s 'add' "''${tempFiles[@]}" > $out
              '';

          # Build a nixidy CRD type generator derivation for a service.
          # Dispatches to either fromChartCRD or fromCRD based on the service's
          # CRD configuration, forwarding only the keys that are present and non-empty.
          # { fromCRD, fromChartCRD } -> string -> service -> derivation
          mkCrdGenerator =
            { fromCRD, fromChartCRD }:
            name: service:
            let
              crdConfig = callServiceCrds service;
              useChartGenerator = crdConfig.chart or null != null || crdConfig.chartAttrs or { } != { };
              useSrcGenerator = crdConfig.src or null != null;
            in
            if useChartGenerator then
              fromChartCRD (
                {
                  inherit name;
                }
                // builtins.intersectAttrs {
                  chart = null;
                  chartAttrs = null;
                  values = null;
                  crds = null;
                  namePrefix = null;
                  attrNameOverrides = null;
                  skipCoerceToList = null;
                  extraOpts = null;
                } crdConfig
              )
            else if useSrcGenerator then
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
