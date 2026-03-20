{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;

  groupType = types.submodule {
    options = {
      labels = mkOption {
        type = types.listOf (
          types.enum [
            "user-role"
            "posix"
            "oauth-grant"
          ]
        );
        default = [ ];
        description = ''
          Labels determine group capabilities and usage:
          - user-role: User-facing role group (identity/login gate)
          - posix: Unix group with gidNumber (requires gid field)
          - oauth-grant: Included in OAuth2 claims for OIDC services
        '';
      };

      gid = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          Group ID for POSIX groups. Required if "posix" label is set.
          Used for both NixOS extraGroups and Kanidm POSIX group attributes.
        '';
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "Human-readable purpose of this group";
      };

      members = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Other groups whose members are transitively included in this group";
      };
    };
  };
in
{
  options.groups = mkOption {
    type = types.attrsOf groupType;
    default = { };
    description = ''
      Shared group definitions provisioned to Kanidm and consumed by NixOS.
      All groups are registered in Kanidm for LDAP exposure and identity management.
    '';
  };
}
