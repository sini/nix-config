{
  features.kanidm.linux =
    {
      secrets,
      environment,
      ...
    }:
    {
      services.kanidm.provision = {
        systems.oauth2.jellyfin =
          let
            domain = environment.getDomainFor "jellyfin";
          in
          {
            displayName = "Jellyfin";
            originUrl = "https://${domain}/sso/OID/redirect/kanidm";
            originLanding = "https://${domain}";
            basicSecretFile = secrets.jellyfin-oidc-client-secret;
            preferShortUsername = true;
            scopeMaps = {
              "media.access" = [
                "openid"
                "profile"
                "groups"
              ];
            };
            claimMaps.roles = {
              joinType = "array";
              valuesByGroup = {
                "media.admins" = [
                  "admin"
                  "user"
                ];
                "media.access" = [ "user" ];
              };
            };
          };
      };
    };
}
