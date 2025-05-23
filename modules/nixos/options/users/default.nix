{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkIf
    mkOption
    types
    ;

  cfg = config.users.deterministicIds;
in
{
  options = {
    users = {
      deterministicIds = mkOption {
        default = { };
        description = ''
          Maps a user or group name to its expected uid/gid values. If a user/group is
          used on the system without specifying a uid/gid, this module will assign the
          corresponding ids defined here, or show an error if the definition is missing.
        '';
        type = types.attrsOf (
          types.submodule {
            options = {
              uid = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "The uid to assign if it is missing in `users.users.<name>`.";
              };
              gid = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "The gid to assign if it is missing in `users.groups.<name>`.";
              };
              subUidRanges = mkOption {
                type = types.listOf (
                  types.submodule {
                    options = {
                      startUid = mkOption {
                        type = types.int;
                        description = "The starting uid for the range.";
                      };
                      count = mkOption {
                        type = types.int;
                        description = "The number of uids in the range.";
                      };
                    };
                  }
                );
                default = [ ];
                description = "Sub UID ranges for the user.";
              };
              subGidRanges = mkOption {
                type = types.listOf (
                  types.submodule {
                    options = {
                      startGid = mkOption {
                        type = types.int;
                        description = "The starting gid for the range.";
                      };
                      count = mkOption {
                        type = types.int;
                        description = "The number of gids in the range.";
                      };
                    };
                  }
                );
                default = [ ];
                description = "Sub GID ranges for the user.";
              };
            };
          }
        );
      };

      users = mkOption {
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              config = {
                uid =
                  let
                    deterministicUid = cfg.${name}.uid or null;
                  in
                  mkIf (deterministicUid != null) (mkDefault deterministicUid);
                subUidRanges =
                  let
                    deterministicSubUidRanges = cfg.${name}.subUidRanges or [ ];
                  in
                  mkIf (deterministicSubUidRanges != [ ]) (mkDefault deterministicSubUidRanges);
                subGidRanges =
                  let
                    deterministicSubGidRanges = cfg.${name}.subGidRanges or [ ];
                  in
                  mkIf (deterministicSubGidRanges != [ ]) (mkDefault deterministicSubGidRanges);
              };
            }
          )
        );
      };

      groups = mkOption {
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              config.gid =
                let
                  deterministicGid = cfg.${name}.gid or null;
                in
                mkIf (deterministicGid != null) (mkDefault deterministicGid);
            }
          )
        );
      };
    };
  };

}
