{ lib, ... }:
{
  options.flake.role = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          nixosModules = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "List of NixOS module names to include for this role";
          };
          homeModules = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "List of Home Manager module names to include for this role";
          };
        };
      }
    );
    default = { };
    description = "NixOS role configurations with statically typed module lists";
  };
}
