{ lib, ... }:
{
  features.kanidm.linux =
    {
      environment,
      users,
      ...
    }:
    let
      kanidmGroups = environment.groups "kanidm";

      # Users with any kanidm-scoped groups get provisioned as persons
      kanidmUsers = lib.filterAttrs (_: user: user.scopedGroups "kanidm" != [ ]) users;
    in
    {
      services.kanidm.provision = {
        groups = lib.mapAttrs (_: g: { members = g.members or [ ]; }) kanidmGroups;

        persons = lib.mapAttrs (username: user: {
          inherit (user.identity) displayName;
          mailAddresses =
            if user.identity.email != null then
              [ user.identity.email ]
            else
              [ "${username}@${environment.email.domain}" ];
          groups = user.scopedGroups "kanidm";
        }) kanidmUsers;
      };
    };
}
