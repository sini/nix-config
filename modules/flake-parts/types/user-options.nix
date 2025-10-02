{
  lib,
  self,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (self.lib.modules)
    featureSubmoduleGenericOptions
    mkFeatureListOpt
    mkFeatureNameOpt
    ;
in
{
  options.flake.users = mkOption {
    type = types.lazyAttrsOf (
      types.submodule (
        { name, ... }:
        {
          options = {
            name = mkOption {
              default = name;
              readOnly = true;
              description = "Username";
            };
            userConfig = mkOption {
              type = types.deferredModule;
              default = { };
              description = "NixOS configuration for this user";
            };
            homeModules = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of Home Manager module names to include for this user";
            };
            features = mkOption {
              type = types.lazyAttrsOf (
                types.submodule (
                  { name, ... }:
                  {
                    options = (builtins.removeAttrs featureSubmoduleGenericOptions [ "nixos" ]) // {
                      name = mkFeatureNameOpt name;
                    };
                  }
                )
              );
              default = { };
              description = ''
                User-specific feature definitions.

                Note that due to these features' nature as user-specific, they
                may not define NixOS modules, which would affect the entire system.
              '';
            };
            baseline = mkOption {
              type = types.submodule {
                options = {
                  features = mkFeatureListOpt ''
                    List of baseline features shared by all of this user's configurations.

                    Note that the "core" feature
                    (`users.<username>.features.core`) will *always* be
                    included in all of the user's configurations.  This
                    follows the same behavior as the "core" feature in
                    the system scope, which is included in all system
                    configurations.
                  '';
                };
              };
              description = "Baseline features and configurations shared by all of this user's configurations";
              default = { };
            };
          };
        }
      )
    );
    default = { };
    description = "User specifications and configurations";
  };
}
