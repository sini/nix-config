# Environment entity registry.
#
# Declares den.environments — the registry consumed by fleet policies
# and scope-engine for environment entity resolution.
{
  den,
  inputs,
  ...
}:
let
  schemaLib = inputs.gen-schema.lib;
in
{
  options.den.environments = schemaLib.mkInstanceRegistry den.schema "environment" {
    description = "Environment definitions for fleet topology and service resolution";
  };
}
