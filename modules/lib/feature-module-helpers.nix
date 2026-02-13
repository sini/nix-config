{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;

  mkDeferredModuleOpt =
    description:
    mkOption {
      inherit description;
      type = types.deferredModule;
      default = { };
    };

  featureSubmoduleGenericOptions = {
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
    nixos = mkDeferredModuleOpt "A NixOS module for this feature";
    home = mkDeferredModuleOpt "A Home-Manager module for this feature";
  };

  mkUsersWithFeaturesOpt =
    description:
    mkOption {
      type = types.lazyAttrsOf (
        types.submodule {
          options = {
            features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                List of features specific to the user.

                While a feature may specify NixOS modules in addition to home
                modules, only home modules will affect configuration.  For this
                reason, users should be encouraged to avoid pointlessly specifying
                their own NixOS modules.
              '';
            };
            configuration = mkDeferredModuleOpt "User-specific home configuration";
          };
        }
      );
      default = { };
      inherit description;
    };

in
{
  flake.lib.modules = {
    inherit
      featureSubmoduleGenericOptions
      mkDeferredModuleOpt
      mkUsersWithFeaturesOpt
      ;
  };
}
