# users — enriches NixOS user accounts from den's user entity data.
#
# Iterates over host.users (resolved by den's policy chain) and configures
# NixOS users with uid/gid, SSH keys, system groups, deterministicIds.
#
# Ported from main:modules/core/users/default.nix
{ den, lib, self, ... }:
{
  den.aspects.core.users = {
    nixos =
      { host, lib, ... }:
      let
        resolvedUsers = host.users or { };

        buildUserConfig = userName: user: let
          uid = user.system.uid or null;
          gid = if user.system.gid or null != null then user.system.gid else uid;
          subUidStart = if uid != null then 100000 + ((uid - 1000) * 65536) else null;

          passwordPath = self + "/.secrets/users/${userName}/hashed-password.age";
          hasPasswordFile = builtins.pathExists passwordPath;
        in {
          users = {
            deterministicIds.${userName} = lib.optionalAttrs (uid != null) {
              inherit uid gid;
              subUidRanges = lib.optional (subUidStart != null) {
                startUid = subUidStart;
                count = 65536;
              };
              subGidRanges = lib.optional (subUidStart != null) {
                startGid = subUidStart;
                count = 65536;
              };
            };

            groups.${userName} = lib.optionalAttrs (gid != null) { inherit gid; };

            users.${userName} = {
              isNormalUser = lib.mkDefault true;
              home = lib.mkDefault "/home/${userName}";
              group = lib.mkDefault userName;
              openssh.authorizedKeys.keys = map (k: k.key) (user.identity.sshKeys or []);
              extraGroups = user.system.systemGroups or [];
              linger = user.system.linger or false;
              description = lib.mkDefault (user.identity.displayName or "");
            } // lib.optionalAttrs hasPasswordFile {
              hashedPasswordFile = "/run/agenix/user-${userName}-password";
            };
          };

          age.secrets = lib.optionalAttrs hasPasswordFile {
            "user-${userName}-password".rekeyFile = passwordPath;
          };
        };
      in
      {
        users.mutableUsers = false;
        imports = lib.mapAttrsToList buildUserConfig resolvedUsers;
      };
  };
}
