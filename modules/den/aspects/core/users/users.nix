# users — enriches NixOS user accounts from den's user entity data.
#
# Parametric aspect (like define-user): takes { host, user } and emits
# NixOS config for uid/gid, SSH keys, system groups, deterministicIds.
#
# Included via den.schema.user.includes so it fires for every resolved user.
#
# Ported from main:modules/core/users/default.nix
{
  lib,
  self,
  config,
  ...
}:
let
  userEnrich =
    { host, user }:
    let
      inherit (user) userName;
      # POSIX group membership is resolved by the scope-engine ACL graph
      # (config.fleet.acl): transitive closure of the user's registry groups
      # over the den.groups membership graph, filtered to posix-scoped groups.
      aclUser = config.fleet.acl.get "host:${host.name}" "resolveUser" userName;
      uid = user.system.uid or null;
      gid = if user.system.gid or null != null then user.system.gid else uid;
      subUidStart = if uid != null then 100000 + ((uid - 1000) * 65536) else null;

      passwordPath = self + "/.secrets/users/${userName}/hashed-password.age";
      hasPasswordFile = builtins.pathExists passwordPath;
    in
    {
      name = "user-enrich/${userName}@${host.name}";

      nixos = {
        users.deterministicIds.${userName} = lib.optionalAttrs (uid != null) {
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

        users.groups.${userName} = lib.optionalAttrs (gid != null) { inherit gid; };

        users.users.${userName} = {
          openssh.authorizedKeys.keys = map (k: k.key) (user.identity.sshKeys or [ ]);
          extraGroups = aclUser.systemGroups;
          linger = user.system.linger or false;
          description = lib.mkDefault (user.identity.displayName or "");
        }
        // lib.optionalAttrs hasPasswordFile {
          hashedPasswordFile = "/run/agenix/user-${userName}-password";
        };

        age.secrets = lib.optionalAttrs hasPasswordFile {
          "user-${userName}-password".rekeyFile = passwordPath;
        };
      };

      # macOS account identity (uid/groups/password) is managed out of band, but
      # the authorized keys are not — without this branch a darwin host installs
      # no keys for the user and sshd (publickey-only) rejects every connection.
      # nix-darwin turns `openssh.authorizedKeys.keys` into a managed
      # /etc/ssh/nix_authorized_keys.d/<user> file + AuthorizedKeysCommand, so
      # mirroring the nixos key set here is all that's needed for SSH parity.
      darwin = {
        users.users.${userName}.openssh.authorizedKeys.keys = map (k: k.key) (user.identity.sshKeys or [ ]);
      };
    };
in
{
  # Wire into user schema includes — fires for every resolved user
  den.schema.user.includes = [ userEnrich ];

  # Host-level mutableUsers setting
  den.aspects.core.users = {
    nixos = {
      users.mutableUsers = false;
    };
  };
}
