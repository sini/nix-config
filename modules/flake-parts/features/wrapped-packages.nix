{
  inputs,
  config,
  lib,
  ...
}:
let
  wrappableFeatures = lib.filterAttrs (_: f: f.wrappable) config.features;

  userScopedFeatures = lib.filterAttrs (
    _: f: f.contextRequirements == [ "user" ] && !f.hasSystemModules
  ) config.features;

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

  # ── Tier 1: no context needed ────────────────────────────────────
  tier1Programs = lib.mapAttrs (_name: feature: {
    homeModules = [ feature.home ];
  }) wrappableFeatures;

  # ── Tier 2: user-scoped (needs user identity) ────────────────────
  # Generates per-user entries: sini-gitkraken, sini-git, etc.
  tier2Programs = lib.concatMapAttrs (
    userName: userConfig:
    lib.mapAttrs' (
      name: feature:
      lib.nameValuePair "${userName}-${name}" {
        homeModules = [ feature.home ];
        extraSpecialArgs = {
          user = userConfig;
        };
      }
    ) userScopedFeatures
  ) config.users;
in
{
  imports = [ inputs.hm-wrapper-modules.flakeModules.default ];

  hmWrappers = {
    home-manager = inputs.home-manager-unstable;
    baseModules = hmBaseModules;
    extraSpecialArgs = { inherit inputs; };
  };

  perSystem = _: {
    hmWrappers.programs = tier1Programs // tier2Programs;
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
