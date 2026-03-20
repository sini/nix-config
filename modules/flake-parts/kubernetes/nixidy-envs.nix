{
  config,
  withSystem,
  lib,
  ...
}:
let
  inherit (config.flake.lib.nixidy-env-helpers) mkEnv mkPerSystemHelpers;
in
{
  flake = {
    nixidyEnvs = lib.genAttrs config.systems (
      system:
      withSystem system (
        { pkgs, ... }:
        lib.mapAttrs (
          env: environment:
          mkEnv {
            inherit
              system
              pkgs
              env
              environment
              ;
            hosts = config.hosts;
          }
        ) config.environments
      )
    );
  };

  perSystem =
    {
      inputs',
      pkgs,
      lib,
      ...
    }@sharedConfig:
    let
      helpers = mkPerSystemHelpers { inherit pkgs sharedConfig; };
      inherit (helpers)
        servicesWithCrds
        mkParsedServiceCrds
        mkCrdGenerator
        ;
    in
    {
      # Pre-parse CRD objects (both source-based and chart-based) at build time.
      # Read back at eval time by getServiceCrdObjects to avoid IFD.
      packages = {
        parsed-crd-objects =
          let
            parsedServices = lib.mapAttrs mkParsedServiceCrds servicesWithCrds;
            serviceNames = lib.attrNames parsedServices;
            # Convert to list to force evaluation upfront, enabling parallel IFD builds
            serviceDrvs = lib.attrValues parsedServices;
          in
          # Force all derivations to be discovered by referencing them in the script.
          # Using toString converts each derivation to a store path (forcing evaluation)
          # without deep recursion (avoiding stack overflow).
          pkgs.runCommand "parsed-crd-objects" { } ''
            # Force all derivations into scope for parallel dependency discovery
            : ${toString serviceDrvs}

            mkdir -p $out
            ${lib.concatMapStringsSep "\n" (name: ''
              cp ${parsedServices.${name}} $out/${name}.json
            '') serviceNames}
          '';

        # Combined build target for k8s-update-manifests: builds all environment
        # packages and writes a manifest.json with metadata + store paths.
        # This reduces 5 separate nix evaluations down to 1.
        nixidy-all-envs =
          let
            system = pkgs.stdenv.hostPlatform.system;
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
            # No deepSeq needed - the runCommand script references all packages directly
            envNames = lib.attrNames envData;
          in
          pkgs.runCommand "nixidy-all-envs" { } ''
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

        generated-crds =
          let
            generators = lib.mapAttrs (mkCrdGenerator {
              inherit (inputs'.nixidy.packages.generators) fromCRD;
            }) servicesWithCrds;
            generatorNames = lib.attrNames generators;
            # Convert to list to force evaluation upfront, enabling parallel IFD builds
            generatorDrvs = lib.attrValues generators;
          in
          # Force all derivations to be discovered by referencing them in the script.
          # Using toString converts each derivation to a store path (forcing evaluation)
          # without deep recursion (avoiding stack overflow).
          pkgs.runCommand "generated-crds" { } ''
            # Force all derivations into scope for parallel dependency discovery
            : ${toString generatorDrvs}

            mkdir -p $out
            ${lib.concatMapStringsSep "\n" (name: ''
              cp ${generators.${name}} $out/${name}.nix
            '') generatorNames}
          '';
      };
    };
}
