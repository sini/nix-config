# Colmena battery: policy-driven hive from host entities.
#
# Deployment tags are derived from each host's resolved aspects
# (host.aspects) — every named aspect becomes a tag by its full identity path
# (e.g. roles/workstation, hardware/audio). host-modules-capture captures the
# raw OS module list without forcing nixosConfigurations.
{
  den,
  lib,
  config,
  inputs,
  withSystem,
  ...
}:
let
  allHosts = lib.foldl' (acc: system: acc // (config.den.hosts.${system} or { })) { } (
    builtins.attrNames (config.den.hosts or { })
  );

  # Channel → nixpkgs input mapping.  Duplicates the table in host.nix but
  # avoids touching self.nixosConfigurations (which forces full host eval).
  channelNixpkgs = {
    nixos-unstable = inputs.nixpkgs-unstable;
    inherit (inputs) nixpkgs-master;
    nixos-stable = inputs.nixpkgs;
    inherit (inputs) nixpkgs-stable-darwin;
  };

  hiveConfig =
    {
      localSystem ? "x86_64-linux",
      ...
    }:
    let
      colmenaModules = config.flake.colmenaModules or { };

      # Deployment tags = every resolved (named) aspect on the host, by full
      # identity path (e.g. "roles/workstation", "hardware/audio"). Anonymous
      # nodes are dropped; deduped + sorted for stable tags.
      aspectTags =
        host:
        lib.sort (a: b: a < b) (lib.unique (map (a: a.identity) (lib.filter (a: a.isNamed) host.aspects)));

      nodes = lib.mapAttrs (name: host: {
        imports = colmenaModules.${name};
        deployment = {
          targetHost =
            let
              inherit (host) ipv4;
            in
            if ipv4 == [ ] then "${name}.ts.json64.dev" else builtins.head ipv4;
          tags = [ (host.environment or "prod") ] ++ aspectTags host;
          allowLocalDeployment = true;
          buildOnTarget = (host.system or localSystem) != localSystem;
          targetUser = host.remote-deployment-user or "sini";
        }
        // lib.optionalAttrs (host.class == "darwin") { systemType = "darwin"; };
      }) allHosts;
    in
    nodes
    // {
      meta = {
        nixpkgs = withSystem localSystem ({ pkgs, ... }: pkgs);
        nix-darwin = inputs.nix-darwin-unstable;
        # Per-node nixpkgs: colmena uses npkgs.path to find eval-config.nix.
        # Derived from host entity channel (cheap) rather than the evaluated
        # nixosConfiguration (expensive).  Bare import avoids colmena's
        # nixpkgsModule double-applying overlays/config.
        nodeNixpkgs = lib.mapAttrs (
          _: host:
          import channelNixpkgs.${host.channel or "nixos-unstable"} {
            inherit (host) system;
          }
        ) allHosts;
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

  # Per-host: capture the raw OS module list without calling nixosSystem.
  # Colmena uses this as node imports — avoids forcing nixosConfigurations
  # just to read the module list back out.
  den.policies.host-modules-capture =
    { host, ... }:
    [
      (den.lib.policy.instantiate {
        name = "${host.name}-modules";
        inherit (host) class;
        instantiate = { modules, ... }: modules;
        intoAttr = [
          "colmenaModules"
          host.name
        ];
      })
    ];

  den.schema.host.includes = [
    den.policies.host-modules-capture
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
