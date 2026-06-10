# nix-on-droid battery: wires Android (Termux) hosts into the fleet.
#
# A host with `class = "droid"` instantiates via
# nix-on-droid.lib.nixOnDroidConfiguration and emits to
# flake.nixOnDroidConfigurations.<name>. The homeManager bridge (a second
# makeHomeEnv) forwards user homeManager aspects into nix-on-droid's singular
# home-manager.config — this is the only aspect reuse a droid host relies on.
#
# Design: a droid host does NOT pull the NixOS host baseline (no `roles.default`,
# no `os`-class route). Its system layer comes from `core.nix-on-droid-base`,
# its tooling from `homeManager`-class aspects (bridged). A few batteries that
# den applies to EVERY host globally still emit NixOS-shaped config that throws
# on nix-on-droid — these are excluded for droid hosts below.
#
# Deploying slab — two paths:
#
#   On-device (primary): on the tablet itself, after the initial nix-on-droid
#   app bootstrap install, run
#       nix-on-droid switch --flake <repo>#slab
#   This is nix-on-droid's native switch flow: it builds
#   nixOnDroidConfigurations.slab.activationPackage and executes the resulting
#   <activationPackage>/activate script.
#
#   Remote (convenience): from a dev shell on a workstation, run
#       deploy-slab [target]      # target defaults to `slab`
#   It builds the slab activationPackage, copies its closure to the tablet's
#   Termux sshd (reachable as `target`) via nix-copy-closure, then runs
#   <activationPackage>/activate over SSH. Best-effort: nix-on-droid has no
#   native remote-switch, so this needs the tablet reachable over SSH and an
#   aarch64 builder/substituter available to build the closure.
{
  den,
  lib,
  inputs,
  config,
  ...
}:
let
  # Channel → nixpkgs / home-manager input tables (mirrors schema/host.nix
  # channels and colmena.nix channelNixpkgs; avoids forcing nixosConfigurations).
  channelNixpkgs = {
    nixos-unstable = inputs.nixpkgs-unstable;
    nixpkgs-master = inputs.nixpkgs-master;
    nixos-stable = inputs.nixpkgs;
    nixpkgs-stable-darwin = inputs.nixpkgs-stable-darwin;
  };
  channelHM = {
    nixos-unstable = inputs.home-manager-unstable;
    nixpkgs-master = inputs.home-manager-master;
    nixos-stable = inputs.home-manager;
    nixpkgs-stable-darwin = inputs.home-manager-stable-darwin;
  };

  # homeManager bridge: reuse className "homeManager" (collects existing HM
  # aspect emissions) but scope to droid hosts and forward into nix-on-droid's
  # singular home-manager.config. supportedOses=["droid"] makes the standard
  # home-manager battery skip droid hosts (its getModule is a lazy option
  # default, only read when detection passes). getModule is empty: nix-on-droid
  # provides the home-manager option itself. schemaIncludes forwarded so a future
  # fleet-wide hm-host schema include is not silently skipped on slab.
  droidHome = den.lib.home-env.makeHomeEnv {
    className = "homeManager";
    ctxName = "droidHm";
    supportedOses = [ "droid" ];
    optionPath = "nixOnDroidHome";
    getModule = { ... }: { };
    forwardPathFn = _: [
      "home-manager"
      "config"
    ];
    schemaIncludes = config.den.schema.hm-host.includes or [ ];
  };
in
{
  flake-file.inputs.nix-on-droid = {
    url = "github:nix-community/nix-on-droid";
    inputs = {
      nixpkgs.follows = "nixpkgs-unstable";
      home-manager.follows = "home-manager-unstable";
    };
  };

  den.classes.droid.description = "nix-on-droid (Android/Termux) system modules";

  # den.batteries.os-user's `user-to-host` policy routes the `user` class into
  # `${host.class}.users.users.<name>` and (via ensureEntry) materialises a
  # `users.users.<name>` skeleton even with no user-class content. On droid that
  # targets a nonexistent `users` option, so exclude the policy for droid hosts.
  # (This one is a top-level den.policies aspect, so policy.exclude matches it by
  # identity. The other two global breakers — the `hostname` battery's inner
  # `hostname/os` emission and `define-user`'s homeManager `home.*` — cannot be
  # reached by exclude, as their effective identity keys are inner/ctx-qualified;
  # they are absorbed instead: a `networking.hostName` shim in the instantiate
  # modules below, and an mkForce on home.username/homeDirectory in
  # core.nix-on-droid-base. All three keep the stock den batteries untouched, so
  # nixos/darwin hosts stay byte-identical.)
  den.policies.drop-user-to-host-on-droid =
    { host, ... }:
    lib.optional (host.class == "droid") (den.lib.policy.exclude den.policies.user-to-host);

  # Registered at default scope (not host scope) to mirror den's os-class.nix:
  # user content is emitted at host AND user scope, so the exclude must fire in
  # every scope where `host` is bound.
  den.default.includes = [ den.policies.drop-user-to-host-on-droid ];

  # Droid-host instantiation. Fires only for class == "droid"; non-mkDefault
  # assignments win over schema/host.nix's mkDefault nixos picks, and setting
  # intoAttr overrides the den-entity default that throws for an unknown class.
  #
  # NOTE on pkgs: den registers each host via `den.lib.policy.instantiate host`
  # (den modules/policies/flake.nix), so the whole host config becomes the
  # instantiate `spec`. resolve.nix's `if spec ? pkgs` therefore keys off
  # whether the *host option* `pkgs` exists. Declaring a host-wide `pkgs`
  # option would make `spec ? pkgs` true for every host — including darwin,
  # whose `darwinSystem` then receives `pkgs = <default>` and breaks. So we do
  # NOT introduce a `pkgs` host option. Instead `instantiate` builds the
  # nix-on-droid nixpkgs (channel + overlay) internally from `config`. den thus
  # stays on its pkgs-less calling convention (`instantiate { modules }`),
  # leaving nixos/darwin hosts untouched.
  den.schema.host.imports = [
    (
      { config, ... }:
      lib.mkIf (config.class == "droid") {
        instantiate =
          { modules, ... }:
          inputs.nix-on-droid.lib.nixOnDroidConfiguration {
            # Fleet nixpkgs policy: allowUnfree. nix-on-droid uses this `pkgs`
            # directly and ignores `nixpkgs.config`, so set it here; the droid HM
            # evaluates its own nixpkgs (useGlobalPkgs = false) so it is also set
            # as an HM sharedModule in core.nix-on-droid-base.
            pkgs = import channelNixpkgs.${config.channel} {
              system = config.system;
              overlays = [ inputs.nix-on-droid.overlays.default ];
              config.allowUnfree = true;
            };
            # Inert option shims absorbing global-battery emissions that nix-on-droid
            # has no option for. Keeping these here (droid-only) means the stock den
            # batteries stay untouched, so nixos/darwin hosts are byte-identical.
            #   nixpkgs.hostPlatform: den's resolve appends `{ nixpkgs.hostPlatform =
            #     mkDefault system; }` for a host with `system` but no `pkgs` option
            #     (this battery deliberately omits a pkgs host option — see NOTE).
            #   networking.hostName: den.batteries.hostname emits
            #     `${host.class}.networking.hostName`; nix-on-droid's networking
            #     submodule has no hostName (Android owns the device hostname).
            modules = [
              (
                { lib, ... }:
                {
                  options.nixpkgs.hostPlatform = lib.mkOption {
                    type = lib.types.raw;
                    default = config.system;
                    description = "Inert shim absorbing den's nixpkgs.hostPlatform default on droid.";
                  };
                  options.networking.hostName = lib.mkOption {
                    type = lib.types.str;
                    default = config.name;
                    description = "Inert shim absorbing den's hostname battery emission on droid.";
                  };
                }
              )
            ]
            ++ modules;
            home-manager-path = channelHM.${config.channel}.outPath;
          };
        intoAttr = [
          "nixOnDroidConfigurations"
          config.name
        ];
      }
    )
    # homeManager option (home-manager.config) for droid hosts
    droidHome.hostConf
  ];

  den.schema.host.includes = [ droidHome.battery ];
  den.schema.user.includes = [ droidHome.userDetect ];

  # Remote-deploy convenience command (see header for both deploy paths).
  # Best-effort: nix-on-droid has no native remote-switch, so this builds the
  # slab activationPackage, copies the closure to the tablet's Termux sshd, and
  # runs `<activationPackage>/activate` over SSH — mirroring nix-on-droid's own
  # `switch` flow (build activationPackage → run <generationDir>/activate).
  den.aspects.devshell.deploy-slab = {
    devshell =
      { pkgs, ... }:
      let
        deploy-slab = pkgs.writeShellApplication {
          name = "deploy-slab";
          runtimeInputs = with pkgs; [
            nix
            openssh
          ];
          text = ''
            target="''${1:-slab}"
            echo "==> Building slab activation package..."
            drv=$(nix build --no-link --print-out-paths ".#nixOnDroidConfigurations.slab.activationPackage")
            echo "==> Copying closure to $target..."
            nix-copy-closure --to "ssh://$target" "$drv"
            echo "==> Activating on $target..."
            ssh "$target" "$drv/activate"
          '';
        };
      in
      {
        packages = [ deploy-slab ];
        commands = [
          {
            package = deploy-slab;
            help = "Remote-deploy the slab nix-on-droid config over SSH (Termux sshd)";
          }
        ];
      };
  };
  den.schema.flake-parts.includes = [ den.aspects.devshell.deploy-slab ];
}
