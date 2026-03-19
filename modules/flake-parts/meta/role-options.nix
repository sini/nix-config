{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.roles = mkOption {
    type = types.attrsOf (
      types.submodule {
        options = {
          features = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "List of feature names to include for this role.";
          };
        };
      }
    );
    default = { };
    description = "NixOS role configurations with feature-based module lists.";
  };
}
