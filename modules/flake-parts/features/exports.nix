{ lib, config, ... }:
{
  flake.featureModules = lib.mapAttrs (
    _name: feature:
    config.flake.lib.compose.mkFeatureEval { inherit feature; }
  ) config.features;
}
