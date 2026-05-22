# Group registry.
#
# Groups are data-only (no isEntity) — they don't get resolved into the
# scope tree. Group data is consumed directly by user access policies
# and scope-engine ACL resolution.
{ lib, den, ... }:
let
  inherit (lib) mkOption types;

  groupType = types.submodule (
    { name, ... }:
    {
      freeformType = types.attrsOf types.anything;
      imports = [ den.schema.group ];
      options.name = mkOption {
        type = types.str;
        default = name;
        description = "Group name (from attrset key)";
      };
    }
  );
in
{
  options.den.groups = mkOption {
    type = types.attrsOf groupType;
    default = { };
    description = "Group definitions for access policy resolution";
  };
}
