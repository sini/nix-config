{ lib, ... }:
{
  options.flake.role = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          features = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "List of feature names to include for this role";
          };
        };
      }
    );
    default = { };
    description = "NixOS role configurations with feature-based module lists";
  };
}
