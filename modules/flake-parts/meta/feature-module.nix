{ self, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (self.lib.modules) featureSubmoduleGenericOptions;
  featureSubmodule =
    { name, ... }:
    {
      options = featureSubmoduleGenericOptions // {
        name = mkOption {
          type = types.str;
          default = name;
          readOnly = true;
          internal = true;
        };
      };
    };
in
{
  options.flake.features = mkOption {
    type = types.lazyAttrsOf (types.submodule featureSubmodule);
    default = { };
  };
}
