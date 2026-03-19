{ lib, ... }:
{
  features.kanidm.linux =
    { environment, ... }:
    {
      services.kanidm.provision = {
        groups = {
          "admins" = { };
          "users".members = [ "admins" ];
        };

        persons = lib.mapAttrs (username: userConfig: {
          inherit (userConfig) displayName;
          mailAddresses =
            if userConfig.email != null then
              [ userConfig.email ]
            else
              [ "${username}@${environment.email.domain}" ];
          inherit (userConfig) groups;
        }) (lib.filterAttrs (_username: userConfig: userConfig.groups != [ ]) environment.users);
      };
    };
}
