{ lib, ... }:
{
  options.flake.user = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          userConfig = lib.mkOption {
            type = lib.types.deferredModule;
            description = "NixOS configuration for this user";
          };
          homeModules = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "List of Home Manager module names to include for this user";
          };
        };
      }
    );
    default = { };
    description = "User configurations with direct module definitions";
  };
}
