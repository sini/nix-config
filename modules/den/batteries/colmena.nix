# Colmena battery: policy-driven hive from host entities.
#
# Aspects emit colmena-tags quirk entries. pipe.collect gathers them
# per-host scope, pipe.to delivers to a sink aspect that emits the
# tags into the flake class keyed by host name.
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
          hostTags = deploymentData.${name} or [ ];
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
  options.flake.colmenaDeployment = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    default = { };
    description = "Per-host colmena tags collected from aspects";
  };

  config = {

  flake-file.inputs.colmena = {
    url = "github:sini/colmena/feat/local-system-detection";
    inputs = {
      nixpkgs.follows = "nixpkgs-unstable";
      flake-compat.follows = "flake-compat";
      flake-utils.follows = "flake-utils";
    };
  };

  # Per-host: collect colmena-tags and route to sink.
  den.policies.collect-colmena-tags =
    _:
    [
      (pipe.from "colmena-tags" [
        (pipe.collect (_: true))
        (pipe.to [ den.aspects.colmena-tag-sink ])
      ])
    ];

  den.schema.host.includes = [
    den.policies.collect-colmena-tags
  ];

  # Sink: receives per-host collected tags and emits into flake class.
  den.aspects.colmena-tag-sink = {
    flake =
      { host, colmena-tags, ... }:
      {
        colmenaDeployment.${host.name} = lib.flatten colmena-tags;
      };
  };

  den.default.includes = [
    den.aspects.colmena-tag-sink
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

  }; # config
}
