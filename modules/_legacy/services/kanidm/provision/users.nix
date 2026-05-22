{ lib, config, ... }:
{
  features.kanidm.linux =
    {
      environment,
      pkgs,
      users,
      ...
    }:
    let
      # All groups are provisioned to Kanidm (for LDAP exposure and future PAM/NSS integration)
      allGroups = config.groups;

      # Users with any oauth-grant or user-role groups get provisioned as persons
      kanidmUsers = lib.filterAttrs (
        _: user: (user.groupsByLabel "oauth-grant" != [ ]) || (user.groupsByLabel "user-role" != [ ])
      ) users;

      # Helper: get all group names for a user (oauth-grant + user-role)
      getUserGroups =
        user: lib.unique ((user.groupsByLabel "oauth-grant") ++ (user.groupsByLabel "user-role"));

      # ========================================================================
      # Extra JSON for kanidm-provision fork features not exposed by upstream
      # NixOS options: enableUnix, gidNumber, loginShell, sshPublicKeys
      # Deep-merged via services.kanidm.provision.extraJsonFile.
      # ========================================================================

      # Groups with "posix" label get enableUnix + gidNumber
      posixGroups = lib.filterAttrs (_: g: lib.elem "posix" (g.labels or [ ])) allGroups;
      extraGroupsJson = lib.mapAttrs (
        _: g: { enableUnix = true; } // lib.optionalAttrs (g.gid != null) { gidNumber = g.gid; }
      ) posixGroups;

      # Persons with enableUnixAccount get enableUnix + uid/gid/sshKeys
      unixPersons = lib.filterAttrs (_: user: user.system.enableUnixAccount or false) kanidmUsers;
      extraPersonsJson = lib.mapAttrs (
        _username: user:
        {
          enableUnix = true;
          loginShell = "/run/current-system/sw/bin/zsh";
        }
        // lib.optionalAttrs (user.system.uid != null) { gidNumber = user.system.uid; }
        // lib.optionalAttrs (user.identity.sshKeys != [ ]) {
          sshPublicKeys = map (k: { inherit (k) tag key; }) user.identity.sshKeys;
        }
      ) unixPersons;

      extraJson =
        lib.optionalAttrs (extraGroupsJson != { }) { groups = extraGroupsJson; }
        // lib.optionalAttrs (extraPersonsJson != { }) { persons = extraPersonsJson; };

      extraJsonFile = pkgs.writeText "kanidm-provision-extra.json" (builtins.toJSON extraJson);
    in
    {
      services.kanidm.provision = {
        # Provision all groups to Kanidm
        groups = lib.mapAttrs (_: g: { members = g.members or [ ]; }) allGroups;

        persons = lib.mapAttrs (username: user: {
          inherit (user.identity) displayName;
          mailAddresses =
            if user.identity.email != null then
              [ user.identity.email ]
            else
              [ "${username}@${environment.email.domain}" ];
          groups = getUserGroups user;
        }) kanidmUsers;

        # Deep-merged with the above — adds enableUnix, gidNumber, sshPublicKeys
        inherit extraJsonFile;
      };
    };
}
