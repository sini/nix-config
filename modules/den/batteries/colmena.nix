# Colmena battery: builds a colmena hive from host entities with lazy
# access to nixos/darwinConfigurations for the full module set.
{
  den,
  lib,
  config,
  inputs,
  self,
  ...
}:
let
  currentSystem = builtins.currentSystem or "x86_64-linux";

  allHosts = lib.foldl' (acc: system: acc // (config.den.hosts.${system} or { })) { } (
    builtins.attrNames (config.den.hosts or { })
  );

  # lib.mapAttrs is lazy per-key — only the targeted host is forced.
  colmenaNodes = lib.mapAttrs (
    name: host:
    let
      isDarwin = host.class == "darwin";
      osConfig =
        if isDarwin then
          self.darwinConfigurations.${name}
        else
          self.nixosConfigurations.${name};
    in
    {
      imports = osConfig._module.args.modules;
      deployment = {
        targetHost =
          let
            ipv4 = host.ipv4 or [ ];
          in
          if ipv4 == [ ] then "${name}.ts.json64.dev" else builtins.head ipv4;
        tags = [ (host.environment or "prod") ];
        allowLocalDeployment = true;
        buildOnTarget = (host.system or currentSystem) != currentSystem;
        targetUser = host.remote-deployment-user or "sini";
      }
      // lib.optionalAttrs isDarwin { systemType = "darwin"; };
    }
  ) allHosts;

  hiveConfig = colmenaNodes // {
    meta = {
      nixpkgs = import inputs.nixpkgs-unstable { system = "x86_64-linux"; };
      nodeSpecialArgs = lib.mapAttrs (
        name: _:
        (self.nixosConfigurations.${name} or self.darwinConfigurations.${name})._module.specialArgs
      ) colmenaNodes;
    };
  };
in
{
  flake-file.inputs.colmena = {
    url = "github:zw3rk/colmena/darwin-support";
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
