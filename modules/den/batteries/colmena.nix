# Colmena battery: builds a colmena hive from host entities with lazy
# access to nixos/darwinConfigurations for the full module set.
#
# meta.localSystem is provided by colmena from the deployer's architecture.
# buildOnTarget and meta.nixpkgs derive from it automatically.
{
  den,
  lib,
  config,
  inputs,
  self,
  withSystem,
  ...
}:
let
  allHosts = lib.foldl' (acc: system: acc // (config.den.hosts.${system} or { })) { } (
    builtins.attrNames (config.den.hosts or { })
  );

  colmenaNodes =
    { localSystem }:
    lib.mapAttrs (
      name: host:
      let
        isDarwin = host.class == "darwin";
        osConfig =
          if isDarwin then self.darwinConfigurations.${name} else self.nixosConfigurations.${name};
      in
      {
        imports = osConfig._module.args.modules;
        deployment = {
          targetHost =
            let
              inherit (host) ipv4;
            in
            if ipv4 == [ ] then "${name}.ts.json64.dev" else builtins.head ipv4;
          tags = [ (host.environment or "prod") ];
          allowLocalDeployment = true;
          buildOnTarget = (host.system or localSystem) != localSystem;
          targetUser = host.remote-deployment-user or "sini";
        }
        // lib.optionalAttrs isDarwin { systemType = "darwin"; };
      }
    ) allHosts;

  hiveConfig =
    args@{ localSystem ? "x86_64-linux", ... }:
    let
      nodes = colmenaNodes { inherit localSystem; };
    in
    nodes
    // {
      meta = {
        nixpkgs = withSystem localSystem ({ pkgs, ... }: pkgs);
        nodeSpecialArgs = lib.mapAttrs (
          name: _:
          (self.nixosConfigurations.${name} or self.darwinConfigurations.${name})._module.specialArgs
        ) nodes;
      };
    };
in
{
  flake-file.inputs.colmena = {
    url = "github:sini/colmena/feat/local-system-detection";
    inputs = {
      nixpkgs.follows = "nixpkgs-unstable";
      flake-compat.follows = "flake-compat";
      flake-utils.follows = "flake-utils";
    };
  };

  flake.colmenaHive = inputs.colmena.lib.makeHive hiveConfig;

  # Emit colmena CLI into devshell via class routing
  den.aspects.devshell.colmena = {
    devshell =
      { inputs', pkgs, ... }:
      let
        colmena = inputs'.colmena.packages.colmena.override {
          nix-eval-jobs = pkgs.lixPackageSets.stable.nix-eval-jobs;
        };
      in
      {
        packages = [ colmena ];
        commands = [
          {
            package = colmena;
            help = "Build and deploy this nix config to nodes";
          }
        ];
      };
  };
  den.schema.flake-parts.includes = [ den.aspects.devshell.colmena ];
}
