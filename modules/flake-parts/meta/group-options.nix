{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;

  groupType = types.submodule {
    options = {
      scope = mkOption {
        type = types.enum [
          "kanidm"
          "unix"
          "system"
        ];
        description = "Scope determines which provisioners consume this group";
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
    description = "Shared group definitions used by Kanidm, Unix accounts, and host login gates";
  };
}
