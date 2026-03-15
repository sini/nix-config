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
          }
        ) config.flake.environments
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
      devshells.default.packages = [ inputs'.nixidy.packages.default ];
      devshells.default.commands = [
        {
          package = sharedConfig.config.packages.k8s-update-manifests;
          name = "k8s-update-manifests";
          help = "Update Kubernetes manifests for nixidy environments";
        }
        {
          package = inputs'.nixidy.packages.default;
          help = "[DEPRECATED] - use k8s-update-manifests instead as it has secret wrapping";
        }
      ];

      # Pre-parse CRD objects (both source-based and chart-based) at build time.
      # Read back at eval time by getServiceCrdObjects to avoid IFD.
      packages = {
        parsed-crd-objects =
          let
            parsedServices = lib.mapAttrs mkParsedServiceCrds servicesWithCrds;
          in
          pkgs.runCommand "parsed-crd-objects" { } ''
            mkdir -p $out
            ${lib.concatMapStringsSep "\n" (name: ''
              ln -s ${parsedServices.${name}} $out/${name}.json
            '') (lib.attrNames parsedServices)}
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
            ) (lib.attrNames envData)}
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
          in
          pkgs.runCommand "generated-crds" { } ''
            mkdir -p $out
            ${lib.concatMapStringsSep "\n" (name: ''
              cp ${generators.${name}} $out/${name}.nix
            '') (lib.attrNames generators)}
          '';
      };
    };
}
