{
  lib,
  self,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (self.lib.modules)
    aspectSubmoduleGenericOptions
    mkAspectListOpt
    mkAspectNameOpt
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
            aspects = mkOption {
              type = types.lazyAttrsOf (
                types.submodule (
                  { name, ... }:
                  {
                    options = (builtins.removeAttrs aspectSubmoduleGenericOptions [ "nixos" ]) // {
                      name = mkAspectNameOpt name;
                    };
                  }
                )
              );
              default = { };
              description = ''
                User-specific aspect definitions.

                Note that due to these aspects' nature as user-specific, they
                may not define NixOS modules, which would affect the entire system.
              '';
            };
            baseline = mkOption {
              type = types.submodule {
                options = {
                  aspects = mkAspectListOpt ''
                    List of baseline aspects shared by all of this user's configurations.

                    Note that the "core" aspect
                    (`users.<username>.aspects.core`) will *always* be
                    included in all of the user's configurations.  This
                    follows the same behavior as the "core" aspect in
                    the system scope, which is included in all system
                    configurations.
                  '';
                };
              };
              description = "Baseline aspects and configurations shared by all of this user's configurations";
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
