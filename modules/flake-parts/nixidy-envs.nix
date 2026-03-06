{
  config,
  inputs,
  withSystem,
  lib,
  ...
}:
let
  inherit (config.flake.meta) repo;
  inherit (config.flake.lib.kubernetes-services) nixidyKubernetesType;
  inherit (config.flake.lib.kubernetes-utils) extractCRDsFromChart;
in
{
  flake = {
    nixidyEnvs = lib.genAttrs config.systems (
      system:
      (withSystem system (
        { pkgs, ... }:
        (lib.mapAttrs (
          env: environment:
          let
            # Collect nixidy modules from services enabled in environment
            defaultServices = [
              "bootstrap"
              "argocd"
              "cert-manager"
              "cilium"
              "envoy-gateway"
              "sops-secrets-operator"
            ];
            enabledServices = lib.unique (defaultServices ++ (environment.kubernetes.services.enabled or [ ]));
            serviceModules = lib.map (serviceName: config.flake.kubernetes.services.${serviceName}.nixidy) (
              lib.filter (serviceName: config.flake.kubernetes.services ? ${serviceName}) enabledServices
            );

            # Extract CRD objects for enabled services
            # Use pre-parsed CRD objects from build-time derivation for better caching
            parsedCrdObjects = withSystem system ({ config, ... }: config.packages.parsed-crd-objects);

            serviceCrdObjects = lib.mapAttrs (
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
              if crdConfig != null then
                if (crdConfig.src or null != null) then
                  # Use pre-parsed JSON from derivation instead of parsing YAML at eval time
                  let
                    parsedFile = parsedCrdObjects + "/${name}.json";
                  in
                  if builtins.pathExists parsedFile then builtins.fromJSON (builtins.readFile parsedFile) else [ ]
                else
                  # Chart-based CRDs - already handled by fromChartCRD generator
                  let
                    klib = inputs.nix-kube-generators.lib { inherit pkgs; };
                  in
                  extractCRDsFromChart (crdConfig // { inherit name klib; })
              else
                [ ]
            ) (lib.filterAttrs (name: _: lib.elem name enabledServices) config.flake.kubernetes.services);
          in
          inputs.nixidy.lib.mkEnv {
            inherit pkgs;
            charts = inputs.nixhelm.chartsDerivations.${system};
            extraSpecialArgs = {
              inherit environment;
              hosts = config.flake.hosts;
              # Expose CRD objects for services to use in bootstrap
              crdObjects = serviceCrdObjects;
            };
            modules = [
              (
                { lib, ... }:

                {
                  # Use flattened nixidy type for direct service access
                  options.kubernetes = lib.mkOption {
                    type = nixidyKubernetesType;
                    default = { };
                    description = "Kubernetes configuration for this nixidy environment";
                  };

                  # Inject environment kubernetes config with flattened services structure
                  config = {
                    # Inject environment values as defaults that nixidy modules can override
                    kubernetes = lib.mapAttrs (
                      name: value:
                      if name == "services" then
                        # Flatten: use services.config as services
                        lib.mapAttrs (_: lib.mkDefault) environment.kubernetes.services.config
                      else
                        lib.mkDefault value
                    ) environment.kubernetes;

                    nixidy = {
                      env = lib.mkDefault env;
                      resourceImports =
                        let
                          # Use the generated-crds package from perSystem
                          generatedCrds = (withSystem system ({ config, ... }: config.packages.generated-crds));

                          # Read all .nix files from the generated-crds derivation
                          allNixFiles = lib.attrNames (
                            lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (
                              builtins.readDir generatedCrds
                            )
                          );

                          # Filter to only include CRD files for enabled services
                          enabledNixFiles = lib.filter (
                            name:
                            let
                              # Extract service name by removing .nix suffix
                              serviceName = lib.removeSuffix ".nix" name;
                            in
                            lib.elem serviceName enabledServices
                          ) allNixFiles;
                        in
                        # Import each generated CRD file as a nixidy module
                        map (name: import (generatedCrds + "/${name}")) enabledNixFiles;

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

                        # Many helm chars will render all resources with the
                        # following labels.
                        # This produces huge diffs when the charts are updated
                        # because the values of these labels change each release.
                        # Here we add a transformer that strips them out after
                        # templating the helm charts in each application.
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
                }
              )
            ]
            # Import service modules for services defined in environment
            ++ serviceModules;
          }
        ) config.flake.environments)
      ))
    );
  };

  perSystem =
    {
      inputs',
      pkgs,
      lib,
      ...
    }@sharedConfig:
    {

      devshells.default.packages = [ inputs'.nixidy.packages.default ];
      devshells.default.commands = [
        {
          package = inputs'.nixidy.packages.default;
          # help = "Manage kubernetes cluster deployment configuration";
          help = "[DEPRECATED] - use k8s-update-manifests instead as it has secret wrapping";
        }
      ];

      # Pre-parse CRD YAML files at build time for caching
      packages.parsed-crd-objects =
        let
          servicesWithSrcCrds = lib.filterAttrs (
            _name: service:
            service.crds != null
            && (
              let
                crdConfig = service.crds (
                  sharedConfig
                  // {
                    inherit inputs;
                  }
                );
              in
              crdConfig.src or null != null
            )
          ) config.flake.kubernetes.services;

          # For each service, create a derivation that parses its YAML CRDs
          parsedServices = lib.mapAttrs (
            name: service:
            let
              crdConfig = service.crds (
                sharedConfig
                // {
                  inherit inputs;
                }
              );
            in
            pkgs.runCommand "parse-${name}-crds"
              {
                nativeBuildInputs = [
                  pkgs.yq-go
                  pkgs.jq
                ];
                src = crdConfig.src;
                crds = builtins.toJSON crdConfig.crds;
              }
              ''
                # Parse each CRD YAML file and extract CustomResourceDefinition objects
                # Collect all CRD objects from all files into a single JSON array
                tempFiles=()
                i=0
                for crd in $(echo "$crds" | jq -r '.[]'); do
                  # Use yq to convert YAML to JSON (handles multi-document YAML)
                  # Then use jq to filter for CRD objects and output as array
                  tempFile="temp_$i.json"
                  yq eval -o=json '.' "$src/$crd" | \
                    jq -s 'map(select(type == "object" and .kind == "CustomResourceDefinition"))' > "$tempFile"
                  tempFiles+=("$tempFile")
                  i=$((i + 1))
                done

                # Combine all arrays into a single array
                jq -s 'add' "''${tempFiles[@]}" > $out
              ''
          ) servicesWithSrcCrds;
        in
        pkgs.runCommand "parsed-crd-objects" { } ''
          mkdir -p $out
          ${lib.concatMapStringsSep "\n" (name: ''
            ln -s ${parsedServices.${name}} $out/${name}.json
          '') (lib.attrNames parsedServices)}
        '';

      packages.generated-crds =
        let
          inherit (inputs'.nixidy.packages.generators) fromCRD fromChartCRD;

          # Generate CRDs from service module definitions
          servicesWithCrds = lib.filterAttrs (
            _name: service: service.crds != null
          ) config.flake.kubernetes.services;

          serviceCrdGenerators = lib.mapAttrs (
            name: service:
            let
              # Call the CRD function with perSystem args
              crdConfig = service.crds (
                sharedConfig
                // {
                  inherit inputs;
                }
              );
              # Determine which generator to use based on configuration
              useChartGenerator = crdConfig.chart or null != null || crdConfig.chartAttrs or { } != { };
              useSrcGenerator = crdConfig.src or null != null;
            in
            if useChartGenerator then
              fromChartCRD (
                {
                  inherit name;
                }
                // (lib.optionalAttrs (crdConfig ? chart) { inherit (crdConfig) chart; })
                // (lib.optionalAttrs (crdConfig ? chartAttrs) { inherit (crdConfig) chartAttrs; })
                // (lib.optionalAttrs (crdConfig ? values) { inherit (crdConfig) values; })
                // (lib.optionalAttrs (crdConfig ? crds) { inherit (crdConfig) crds; })
                // (lib.optionalAttrs (crdConfig ? namePrefix) { inherit (crdConfig) namePrefix; })
                // (lib.optionalAttrs (crdConfig ? attrNameOverrides) { inherit (crdConfig) attrNameOverrides; })
                // (lib.optionalAttrs (crdConfig ? skipCoerceToList) { inherit (crdConfig) skipCoerceToList; })
                // (lib.optionalAttrs (crdConfig ? extraOpts) { inherit (crdConfig) extraOpts; })
              )
            else if useSrcGenerator then
              fromCRD (
                {
                  inherit name;
                  src = crdConfig.src;
                  crds = crdConfig.crds;
                }
                // (lib.optionalAttrs (crdConfig.namePrefix or "" != "") { namePrefix = crdConfig.namePrefix; })
                // (lib.optionalAttrs (crdConfig.attrNameOverrides or { } != { }) {
                  attrNameOverrides = crdConfig.attrNameOverrides;
                })
                // (lib.optionalAttrs (crdConfig.skipCoerceToList or { } != { }) {
                  skipCoerceToList = crdConfig.skipCoerceToList;
                })
              )
            else
              throw "Service '${name}' has CRDs defined but neither 'src' nor 'chart'/'chartAttrs' are set"
          ) servicesWithCrds;

          generators = serviceCrdGenerators;
        in
        pkgs.runCommand "generated-crds" { } ''
          mkdir -p $out
          ${lib.concatMapStringsSep "\n" (name: ''
            cp ${generators.${name}} $out/${name}.nix
          '') (lib.attrNames generators)}
        '';
    };
}
