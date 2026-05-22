{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
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
