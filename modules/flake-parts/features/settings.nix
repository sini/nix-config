# Feature settings resolution with multi-layer merging.
{ lib, ... }:
let
  inherit (lib) mkOption types;

  # Generate a typed settings option from features.
  # settingsKey selects which field to read from features ("settings" or "user-settings").
  mkSettingsOpt =
    settingsKey: featuresConfig: description:
    let
      relevant = lib.filterAttrs (_: f: f.${settingsKey} or { } != { }) featuresConfig;
    in
    mkOption {
      type = types.submodule {
        options = lib.mapAttrs (
          name: feature:
          mkOption {
            type = types.submodule { options = feature.${settingsKey}; };
            default = { };
            description = "Settings for the ${name} feature";
          }
        ) relevant;
      };
      default = { };
      inherit description;
    };

  # System-level settings (hosts/environments)
  mkFeatureSettingsOpt = mkSettingsOpt "settings";

  # User-level settings (per-user on canonical/env/host users)
  mkFeatureUserSettingsOpt = mkSettingsOpt "user-settings";

  # Resolve feature settings by merging layers via evalModules.
  # settingsKey selects "settings" or "user-settings" from features.
  # Priority (lowest to highest): feature defaults → envSettings (mkDefault) → hostSettings → userSettings
  resolveFeatureSettings =
    {
      settingsKey ? "settings",
      activeFeatureNames,
      featuresConfig,
      layers ? [ ],
    }:
    let
      relevantFeatures = lib.filterAttrs (
        name: f: lib.elem name activeFeatureNames && f.${settingsKey} or { } != { }
      ) featuresConfig;

      settingsOptions = lib.mapAttrs (
        _name: feature:
        mkOption {
          type = types.submodule { options = feature.${settingsKey}; };
          default = { };
        }
      ) relevantFeatures;

      # Filter each layer's config to only include relevant features
      filteredLayers = map (
        layer: args:
        let
          result = if lib.isFunction layer then layer args else layer;
          filteredConfig = lib.intersectAttrs relevantFeatures (result.config or { });
        in
        result // { config = filteredConfig; }
      ) layers;

      evaluated = lib.evalModules {
        modules = [
          { options = settingsOptions; }
        ]
        ++ filteredLayers;
      };
    in
    evaluated.config;
in
{
  config.flake.lib.features = {
    inherit
      mkFeatureSettingsOpt
      mkFeatureUserSettingsOpt
      resolveFeatureSettings
      ;
  };
}
