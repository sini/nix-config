{
  inputs,
  config,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      wlib = inputs.hm-wrapper-modules.lib;

      # ── Tier 1: no context needed (auto-discovered) ──────────────────
      wrappableFeatures = lib.filterAttrs (_: f: f.wrappable) config.features;

      # Base modules for isolated HM evaluation:
      # - Persistence stub (same pattern as Darwin impermanence shim)
      # - Our stylix feature's home config (theme, fonts, colors, cursor, icons)
      hmBaseModules = [
        {
          options.home.persistence = lib.mkOption {
            type = lib.types.anything;
            default = { };
            description = "Stub persistence option for wrapper evaluation (no-op).";
          };
        }
        config.features.stylix.home
      ];

      mkWrapped =
        name: feature: extraArgs:
        let
          base = wlib.wrapHomeModule {
            inherit pkgs;
            homeModules = hmBaseModules ++ [ feature.home ];
            programName = name;
            home-manager = inputs.home-manager-unstable;
            extraSpecialArgs = {
              inherit inputs;
            }
            // extraArgs;
          };
        in
        base.wrap {
          imports = [ wlib.modules.bwrapConfig ];
          bwrapConfig.binds.ro = wlib.mkBinds base.passthru.hmAdapter;
          env.XDG_CONFIG_HOME = lib.mkForce null;
        };

      tier1Packages = builtins.mapAttrs (name: feature: mkWrapped name feature { }) wrappableFeatures;

      # ── Tier 2: user-scoped (needs user identity) ────────────────────
      userScopedFeatures = lib.filterAttrs (
        _: f: f.contextRequirements == [ "user" ] && !f.hasSystemModules
      ) config.features;

      mkUserPackages =
        _userName: userConfig:
        builtins.mapAttrs (name: feature: mkWrapped name feature { user = userConfig; }) userScopedFeatures;

      # Generate per-user package sets: { sini = { gitkraken, git, ... }; ... }
      userPackages = lib.mapAttrs mkUserPackages config.users;
    in
    {
      packages = tier1Packages;
      legacyPackages = userPackages;
    };

  # Expose wrappability metadata for introspection
  flake.featureMeta = lib.mapAttrs (_: f: {
    inherit (f)
      wrappable
      homeArgs
      contextRequirements
      hasSystemModules
      ;
  }) config.features;
}
