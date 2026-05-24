# Colmena battery: adds a second policy.instantiate per host that
# collects the full module set (including mainModule) into colmenaNodes,
# then builds the hive with deployment metadata from host entities.
{
  den,
  lib,
  config,
  inputs,
  ...
}:
let
  currentSystem = builtins.currentSystem or "x86_64-linux";

  allHosts = lib.foldl' (acc: system: acc // (config.den.hosts.${system} or { })) { } (
    builtins.attrNames (config.den.hosts or { })
  );

  colmenaNodes = lib.mapAttrs (
    name: modules:
    let
      host = allHosts.${name} or { };
      isDarwin = (host.class or "") == "darwin";
    in
    {
      imports = modules;
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
  ) (config.flake.colmenaNodes or { });

  hiveConfig = colmenaNodes // {
    meta = {
      nixpkgs = import inputs.nixpkgs-unstable { system = "x86_64-linux"; };
    };
  };
in
{
  # Second instantiate per host — same hostCfg (includes mainModule),
  # but collects into colmenaNodes instead of nixos/darwinConfigurations.
  den.policies.host-to-colmena =
    { host, ... }:
    [
      (den.lib.policy.instantiate (
        host
        // {
          intoAttr = [
            "colmenaNodes"
            host.name
          ];
          instantiate = { modules, ... }: modules;
        }
      ))
    ];

  den.schema.host.includes = [ den.policies.host-to-colmena ];

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
