{ self, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (self.lib.modules) featureSubmoduleGenericOptions mkFeatureNameOpt;
  featureSubmodule =
    { name, ... }:
    {
      options = featureSubmoduleGenericOptions // {
        name = mkFeatureNameOpt name;
      };
    };
in
{
  options.flake.features = mkOption {
    type = types.lazyAttrsOf (types.submodule featureSubmodule);
    default = { };
  };
}
