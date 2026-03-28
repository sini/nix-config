# Expose features as flake outputs with composition chains attached.
{ lib, config, inputs, ... }:
let
  hmBaseModules = [
    {
      options.home.persistence = lib.mkOption {
        type = lib.types.anything;
        default = { };
        description = "Stub persistence option for wrapper evaluation.";
      };
    }
    config.features.stylix.home
  ];
in
{
  flake.featureModules = lib.mapAttrs (
    _name: feature:
    config.flake.lib.features.compose.mkFeatureEval {
      inherit feature;
      wlib = inputs.hm-wrapper-modules.lib;
      home-manager = inputs.home-manager-unstable;
      baseModules = hmBaseModules;
    }
  ) config.features;
}
