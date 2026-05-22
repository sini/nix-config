# Environment entity registry.
#
# Declares den.environments — the registry consumed by fleet policies
# and scope-engine for environment entity resolution.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.den.environments = mkOption {
    type = types.attrsOf (types.attrsOf types.anything);
    default = { };
    description = "Environment definitions for fleet topology and service resolution";
  };
}
