{ lib, inputs, ... }:
let
  inherit (lib) mkOption types;
  schemaLib = inputs.gen-schema.lib;
in
{
  den.schema.group.validators = [
    (schemaLib.mkValidator "posix-needs-gid" (
      { labels, gid, ... }: !(lib.elem "posix" labels) || gid != null
    ) "groups with the 'posix' label must have a gid set")
  ];
  den.schema.group.imports = [
    (_: {
      options = {
        labels = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Classification labels for the group (e.g., posix, oauth-grant, user-role)";
        };

        description = mkOption {
          type = types.str;
          default = "";
          description = "Human-readable description of the group";
        };

        members = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Other groups whose members inherit membership in this group";
        };

        gid = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "POSIX group ID number (required for groups with the 'posix' label)";
        };
      };
    })
  ];
}
