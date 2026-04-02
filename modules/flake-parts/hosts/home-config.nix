# Per-user home-manager configuration with feature resolution.
{
  lib,
  self,
  config,
  ...
}:
{
  flake.lib.hosts =
    let
      inherit (self.lib.features.collection) collectPlatformHomeModules;
      inherit (self.lib.features) resolveFeatureSettings;
      inherit (self.lib.features.resolver) resolveFeatures coreFeatures;

      makeHomeConfig =
        {
          resolvedUser,
          allHostFeatures,
          system ? "x86_64-linux",
          fullContext ? { },
          dispatchableArgs ? [ ],
        }:
        let
          includeHostFeatures = resolvedUser.system.include-host-features or true;
          userExtraFeatures = resolvedUser.system.extra-features or [ ];
          userExclusions = resolvedUser.system.excluded-features or [ ];

          # Combine host features with user-specific features
          userExtraFeatureNames = userExtraFeatures;

          # Validate user extra-features have home modules
          systemOnlyFeatures = lib.filter (
            name:
            let
              f = config.features.${name};
            in
            f.home == { } && (f.system or { } != { } || f.linux != { } || f.darwin != { } || f.os or { } != { })
          ) userExtraFeatureNames;

          _validate =
            assert lib.assertMsg (systemOnlyFeatures == [ ])
              "User extra-features must have home modules. System-only features should be added to the host: ${lib.concatStringsSep ", " systemOnlyFeatures}";
            true;

          # Build the feature list for this user
          coreFeatureNames = coreFeatures;
          hostFeatureNames = map (f: f.name) (
            if includeHostFeatures then
              allHostFeatures
            else
              lib.filter (f: lib.elem f.name coreFeatureNames) allHostFeatures
          );

          allFeatureNames = lib.unique (hostFeatureNames ++ userExtraFeatureNames);

          # Use the resolver for proper dependency resolution
          resolved = builtins.seq _validate (resolveFeatures {
            featuresConfig = config.features;
            hostFeatures = allFeatureNames;
            hostExclusions = userExclusions;
          });

          resolvedFeatures = builtins.attrValues resolved.features;
          userActiveProviders = builtins.attrValues (resolved.providers or { });

          homeModules = collectPlatformHomeModules {
            features = resolvedFeatures;
            activeProviders = userActiveProviders;
            inherit system dispatchableArgs;
            availableContext = fullContext // {
              user = augmentedUser;
              osConfig = true;
            };
          };

          # Resolve per-user settings (feature defaults → canonical → env → host user)
          usl =
            resolvedUser.system.userSettingsLayers or {
              canonical = { };
              env = { };
              host = { };
            };
          resolvedUserSettings = resolveFeatureSettings {
            settingsKey = "user-settings";
            activeFeatureNames = map (f: f.name) resolvedFeatures;
            featuresConfig = config.features;
            layers = [
              # Canonical user settings (lowest user priority)
              (
                { lib, ... }:
                {
                  config = lib.mapAttrs (_: v: lib.mapAttrs (_: lib.mkDefault) v) usl.canonical;
                }
              )
              # Environment user settings (middle)
              (
                { lib, ... }:
                {
                  config = lib.mapAttrs (_: v: lib.mapAttrs (_: lib.mkDefault) v) usl.env;
                }
              )
              # Host user settings (highest)
              (_: { config = usl.host; })
            ];
          };

          # Augment user with resolved settings
          augmentedUser = resolvedUser // {
            settings = resolvedUserSettings;
          };
        in
        {
          imports = homeModules ++ [
            { _module.args.user = augmentedUser; }
          ];
        };
    in
    {
      inherit makeHomeConfig;
    };
}
