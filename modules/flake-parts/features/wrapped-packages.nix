{ inputs, config, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      wlib = inputs.nix-wrapper-modules.lib;

      # Automatically discover wrappable features (Tier 1: no user/host/environment context).
      # Features are wrappable when their .home module only uses standard HM args.
      wrappableFeatures = lib.filterAttrs (_: f: f.wrappable) config.features;

      mkWrapped =
        name: feature:
        let
          base = wlib.wrapHomeModule {
            inherit pkgs;
            homeModules = [ feature.home ];
            programName = name;
            home-manager = inputs.home-manager-unstable;
            extraSpecialArgs = { inherit inputs; };
          };
        in
        base.wrap {
          imports = [ wlib.modules.bwrapConfig ];
          bwrapConfig.binds.ro = wlib.mkBinds base.passthru.hmAdapter;
          env.XDG_CONFIG_HOME = lib.mkForce null;
        };
    in
    {
      packages = builtins.mapAttrs mkWrapped wrappableFeatures;
    };

  # Expose wrappability metadata for introspection
  flake.featureMeta = lib.mapAttrs (_: f: {
    inherit (f) wrappable homeArgs contextRequirements hasSystemModules;
  }) config.features;
}
