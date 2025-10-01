{ lib, ... }:
{
  options.flake.role = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          aspects = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "List of aspect names to include for this role";
          };
        };
      }
    );
    default = { };
    description = "NixOS role configurations with aspect-based module lists";
  };
}
