# Composition chain factory for feature evaluation and packaging.
{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkFeatureEval =
    {
      feature,
      providers ? [ ],
      wlib ? throw "wlib not provided — cannot call .package without hm-wrapper-modules",
      home-manager ? throw "home-manager not provided — cannot call .package",
      baseModules ? [ ],
    }:
    let
      defaults = {
        inherit wlib home-manager baseModules;
      };

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

      coreModules = [
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

      result = lib.evalModules { modules = coreModules; };

      attachChain =
        evalResult:
        let
          cfg = evalResult.config;
        in
        cfg
        // {
          eval =
            module:
            evalResult.extendModules {
              modules = lib.toList module;
            };
          apply =
            module:
            attachChain (
              evalResult.extendModules {
                modules = lib.toList module;
              }
            );
          package =
            {
              pkgs,
              home-manager ? defaults.home-manager,
              baseModules ? defaults.baseModules,
              extraSpecialArgs ? { },
              mainPackage ? null,
              programName ? cfg._meta.name,
            }:
            let
              isDarwin = pkgs.stdenv.isDarwin;
              isLinux = pkgs.stdenv.isLinux;

              homeModules =
                [ cfg._classModules.home ]
                ++ lib.optional isLinux (cfg._classModules.homeLinux or { })
                ++ lib.optional isDarwin (cfg._classModules.homeDarwin or { });

              base = defaults.wlib.wrapHomeModule {
                inherit
                  pkgs
                  home-manager
                  mainPackage
                  programName
                  extraSpecialArgs
                  ;
                homeModules = baseModules ++ homeModules;
              };
            in
            base.wrap (
              { config, lib, ... }:
              {
                imports = [ defaults.wlib.modules.bwrapConfig ];
                bwrapConfig.binds.ro = defaults.wlib.mkBinds base.passthru.hmAdapter;
                env.XDG_CONFIG_HOME = lib.mkIf config.bwrapConfig.enable (lib.mkForce null);
              }
            );
          _evalResult = evalResult;
        };
    in
    attachChain result;
in
{
  config.flake.lib.features.compose = {
    inherit mkFeatureEval;
  };
}
