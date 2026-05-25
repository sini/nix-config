# Colmena battery: policy-driven hive from host entities.
#
# Each host's colmena-tags quirk is piped into a colmena class.
# policy.instantiate collects the class per-host into
# flake.colmenaDeployment.<host>, then the hive is assembled
# from host entities + collected deployment data.
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
  inherit (den.lib.policy) pipe;

  allHosts = lib.foldl' (acc: system: acc // (config.den.hosts.${system} or { })) { } (
    builtins.attrNames (config.den.hosts or { })
  );

  hiveConfig =
    { localSystem ? "x86_64-linux", ... }:
    let
      deploymentData = config.flake.colmenaDeployment or { };

      nodes = lib.mapAttrs (
        name: host:
        let
          isDarwin = host.class == "darwin";
          osConfig =
            if isDarwin then self.darwinConfigurations.${name} else self.nixosConfigurations.${name};
          hostTags = deploymentData.${name}.tags or [ ];
        in
        {
          imports = osConfig._module.args.modules;
          deployment = {
            targetHost =
              let
                inherit (host) ipv4;
              in
              if ipv4 == [ ] then "${name}.ts.json64.dev" else builtins.head ipv4;
            tags = [ (host.environment or "prod") ] ++ hostTags;
            allowLocalDeployment = true;
            buildOnTarget = (host.system or localSystem) != localSystem;
            targetUser = host.remote-deployment-user or "sini";
          }
          // lib.optionalAttrs isDarwin { systemType = "darwin"; };
        }
      ) allHosts;
    in
    nodes
    // {
      meta = {
        nixpkgs = withSystem localSystem ({ pkgs, ... }: pkgs);
        nix-darwin = inputs.nix-darwin-unstable;
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

  # Colmena class — aspects emit colmena-tags into this class via pipe routing.
  den.classes.colmena.description = "Colmena deployment metadata";

  # Per-host: instantiate colmena class modules into flake.colmenaDeployment.<host>.
  den.policies.host-to-colmena =
    { host, ... }:
    [
      (den.lib.policy.instantiate {
        name = "${host.name}-colmena";
        class = "colmena";
        instantiate =
          { colmena-tags, ... }:
          {
            tags = lib.flatten colmena-tags;
          };
        intoAttr = [
          "colmenaDeployment"
          host.name
        ];
      })
    ];

  # Pipe colmena-tags quirk into the colmena class.
  den.policies.collect-colmena-tags =
    _:
    [
      (pipe.from "colmena-tags" [
        (pipe.collect (_: true))
      ])
    ];

  den.schema.host.includes = [
    den.policies.host-to-colmena
    den.policies.collect-colmena-tags
  ];

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
