{ lib, config, ... }:
{
  features.kanidm.linux =
    {
      environment,
      users,
      ...
    }:
    let
      # All groups are provisioned to Kanidm (for LDAP exposure and future PAM/NSS integration)
      allGroups = config.groups;

      # Users with any oauth-grant or user-role groups get provisioned as persons
      # This includes both identity users (oauth-grant) and system users (user-role login gates)
      kanidmUsers = lib.filterAttrs (
        _: user: (user.groupsByLabel "oauth-grant" != [ ]) || (user.groupsByLabel "user-role" != [ ])
      ) users;

      # Helper: get all group names for a user (oauth-grant + user-role)
      getUserGroups =
        user: lib.unique ((user.groupsByLabel "oauth-grant") ++ (user.groupsByLabel "user-role"));
    in
    {
      services.kanidm.provision = {
        # Provision all groups to Kanidm (identity, login gates, POSIX groups, OAuth grants)
        groups = lib.mapAttrs (_: g: { members = g.members or [ ]; }) allGroups;

        # TODO: Set POSIX attributes for groups with "posix" label
        # This requires Kanidm CLI commands after group creation:
        #   kanidm group posix set --name <groupname> --gidnumber <gid>
        # Implementation: Add to services.kanidm.provision.autoProvision or custom systemd service

        persons = lib.mapAttrs (username: user: {
          inherit (user.identity) displayName;
          mailAddresses =
            if user.identity.email != null then
              [ user.identity.email ]
            else
              [ "${username}@${environment.email.domain}" ];
          # Include both oauth-grant and user-role groups
          groups = getUserGroups user;
        }) kanidmUsers;
      };
    };
}
