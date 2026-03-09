{
  flake.features.kanidm.nixos =
    {
      config,
      environment,
      ...
    }:
    {
      services.kanidm.provision = {
        groups = {
          "media.access".members = [ "users" ];
          "media.admins".members = [ "admins" ];
        };

        systems.oauth2.jellyfin =
          let
            domain = environment.getDomainFor "jellyfin";
          in
          {
            displayName = "Jellyfin";
            originUrl = "https://${domain}/sso/OID/redirect/kanidm";
            originLanding = "https://${domain}";
            basicSecretFile = config.age.secrets.jellyfin-oidc-client-secret.path;
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
