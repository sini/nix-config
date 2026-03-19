{ lib, ... }:
let
  inherit (lib) mkOption types;

  # Wraps a deferred module with metadata for better debugging
  wrapModuleWithMetadata = featureName: modulePath: module:
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

  featureSubmodule =
    { name, ... }:
    {
      options = {
        requires = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of names of features required by this feature";
        };
        excludes = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of names of features to exclude from this feature (prevents the feature and its requires from being added)";
        };

        # Cross-platform system module (included on both NixOS and Darwin)
        system = mkDeferredModuleOptWithMetadata name "system" "A cross-platform system module for this feature (NixOS and Darwin)";

        # Platform-specific system modules (for config that only applies to one platform)
        linux = mkDeferredModuleOptWithMetadata name "linux" "A Linux-specific system module for this feature (NixOS only)";
        darwin = mkDeferredModuleOptWithMetadata name "darwin" "A Darwin-specific system module for this feature (macOS only)";

        # Home-manager module (works on all platforms)
        home = mkDeferredModuleOptWithMetadata name "home" "A Home-Manager module for this feature";

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
  options.features = mkOption {
    type = types.lazyAttrsOf (types.submodule featureSubmodule);
    default = { };
    description = "Feature definitions with NixOS and Home-Manager modules.";
  };
}
