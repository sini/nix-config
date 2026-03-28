# Generate standalone wrapped packages from wrappable features.
{
  config,
  lib,
  ...
}:
let
  wrappableFeatures = lib.filterAttrs (_: f: f.wrappable) config.features;

  userScopedFeatures = lib.filterAttrs (
    _: f: f.contextRequirements == [ "user" ] && !f.hasSystemModules
  ) config.features;
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages =
        # Tier 1: no context needed — direct .package
        (lib.mapAttrs (
          name: _: config.flake.featureModules.${name}.package { inherit pkgs; }
        ) wrappableFeatures)
        //
        # Tier 2: user-scoped — inject user via extraSpecialArgs
        (lib.concatMapAttrs (
          userName: userConfig:
          lib.mapAttrs' (
            name: _:
            lib.nameValuePair "${userName}-${name}" (
              config.flake.featureModules.${name}.package {
                inherit pkgs;
                extraSpecialArgs = {
                  user = userConfig;
                };
              }
            )
          ) userScopedFeatures
        ) config.users);
    };

  # Expose wrappability metadata for introspection
  flake.featureMeta = lib.mapAttrs (
    _: f: {
      inherit (f)
        wrappable
        homeArgs
        contextRequirements
        hasSystemModules
        ;
    }
  ) config.features;
}
