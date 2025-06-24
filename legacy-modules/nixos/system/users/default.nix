{ config, lib, ... }:
let
  inherit (lib)
    concatLists
    flip
    mapAttrsToList
    ;
in
{
  config = {
    assertions =
      concatLists (
        flip mapAttrsToList config.users.users (
          name: user: [
            {
              assertion = user.uid != null;
              message = "non-deterministic uid detected for '${name}', please assign one via `users.deterministicIds`";
            }
            {
              assertion = !user.autoSubUidGidRange;
              message = "non-deterministic subUids/subGids detected for: ${name}";
            }
          ]
        )
      )
      ++ flip mapAttrsToList config.users.groups (
        name: group: {
          assertion = group.gid != null;
          message = "non-deterministic gid detected for '${name}', please assign one via `users.deterministicIds`";
        }
      );
  };
}
