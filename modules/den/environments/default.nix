# Environment entity registry.
#
# Declares den.environments — the registry consumed by fleet policies
# and scope-engine for environment entity resolution.
{ lib, den, ... }:
let
  inherit (lib) mkOption types;

  environmentType = types.submodule (
    { name, ... }:
    {
      freeformType = types.attrsOf types.anything;
      imports = [ den.schema.environment ];
      options.name = mkOption {
        type = types.str;
        default = name;
        description = "Environment name (from attrset key)";
      };
    }
  );
in
{
  options.den.environments = mkOption {
    type = types.attrsOf environmentType;
    default = { };
    description = "Environment definitions for fleet topology and service resolution";
  };
}
