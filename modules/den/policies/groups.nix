# Group registry.
#
# Groups are data-only (no isEntity) — they don't get resolved into the
# scope tree. Group data is consumed directly by user access policies
# and scope-engine ACL resolution.
{
  den,
  inputs,
  ...
}:
let
  schemaLib = (inputs.gen.lib.mkGenLibs { }).schema;
in
{
  options.den.groups = schemaLib.mkInstanceRegistry den.schema.group {
    description = "Group definitions for access policy resolution";
  };
}
