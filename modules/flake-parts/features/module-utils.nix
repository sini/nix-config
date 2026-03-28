{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkDeferredModuleOpt =
    description:
    mkOption {
      inherit description;
      type = types.deferredModule;
      default = { };
    };

  # Wraps a deferred module with metadata for better debugging
  wrapModuleWithMetadata =
    featureName: modulePath: module:
    if module == { } then
      module
    else
      {
        _file = "flake.nix#features.${featureName}.${modulePath}";
        imports = [ module ];
      };

  # Create a deferred module option with metadata wrapping
  mkDeferredModuleOptWithMetadata =
    featureName: modulePath: description:
    mkOption {
      inherit description;
      type = types.deferredModule;
      default = { };
      apply = wrapModuleWithMetadata featureName modulePath;
    };

  # Extract function argument names from a module value.
  # Returns [] for plain attrsets (no function args = no context needed).
  extractModuleArgs =
    module:
    if builtins.isFunction module then builtins.attrNames (builtins.functionArgs module) else [ ];
in
{
  config.flake.lib.features = {
    inherit
      mkDeferredModuleOpt
      wrapModuleWithMetadata
      mkDeferredModuleOptWithMetadata
      extractModuleArgs
      ;
  };
}
