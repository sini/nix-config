{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkFeatureEval =
    {
      feature,
      providers ? [ ],
    }:
    let
      # Build settings options from feature + providers
      featureSettings = feature.settings or { };
      providerSettings = lib.foldl' (acc: p: acc // (p.settings or { })) { } providers;
      allSettings = featureSettings // providerSettings;

      featureUserSettings = feature.user-settings or { };
      providerUserSettings = lib.foldl' (acc: p: acc // (p.user-settings or { })) { } providers;
      allUserSettings = featureUserSettings // providerUserSettings;

      settingsOpts = lib.optionalAttrs (allSettings != { }) {
        ${feature.name} = mkOption {
          type = types.submodule { options = allSettings; };
          default = { };
        };
      };

      userSettingsOpts = lib.optionalAttrs (allUserSettings != { }) {
        ${feature.name} = mkOption {
          type = types.submodule { options = allUserSettings; };
          default = { };
        };
      };

      baseModules = [
        {
          options = {
            settings = mkOption {
              type = types.submodule { options = settingsOpts; };
              default = { };
            };
            user-settings = mkOption {
              type = types.submodule { options = userSettingsOpts; };
              default = { };
            };
            _classModules = mkOption {
              type = types.raw;
              internal = true;
              default = {
                inherit (feature)
                  home
                  os
                  linux
                  darwin
                  ;
                system = feature.system or { };
                homeLinux = feature.homeLinux or { };
                homeDarwin = feature.homeDarwin or { };
              };
            };
            _meta = mkOption {
              type = types.raw;
              internal = true;
              default = {
                inherit (feature) name;
                inherit providers;
              };
            };
          };
        }
      ];

      result = lib.evalModules { modules = baseModules; };

      attachChain =
        evalResult:
        let
          cfg = evalResult.config;
        in
        cfg
        // {
          # .eval returns the raw evalModules result
          eval =
            module:
            evalResult.extendModules {
              modules = lib.toList module;
            };
          # .apply returns config with chain re-attached
          apply =
            module:
            attachChain (
              evalResult.extendModules {
                modules = lib.toList module;
              }
            );
          # .wrap stubbed for Phase 4
          wrap =
            _module: throw "feature.wrap is not yet implemented (Phase 4: hm-wrapper-modules integration)";
          _evalResult = evalResult;
        };
    in
    attachChain result;
in
{
  config.flake.lib.compose = {
    inherit mkFeatureEval;
  };
}
