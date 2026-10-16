# Colmena battery: policy-driven hive from host entities.
#
# Address, user and tags come from the host's tool-neutral deployment record
# (schema/deployment.nix), shared with the panix battery. host-modules-capture
# captures the raw OS module list without forcing nixosConfigurations.
{
  den,
  lib,
  config,
  inputs,
  withSystem,
  ...
}:
let
  allHosts = lib.filterAttrs (_: h: (h.class or "nixos") != "droid") (
    lib.foldl' (acc: system: acc // (config.den.hosts.${system} or { })) { } (
      builtins.attrNames (config.den.hosts or { })
    )
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

      nodes = lib.mapAttrs (name: host: {
        imports = colmenaModules.${name};
        deployment = {
          targetHost = host.deployment.address;
          inherit (host.deployment) tags;
          allowLocalDeployment = true;
          buildOnTarget = (host.system or localSystem) != localSystem;
          targetUser = host.deployment.user;
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
          nix-eval-jobs = pkgs.nix-eval-jobs;
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
