{
  features.kanidm.linux =
    {
      config,
      environment,
      ...
    }:
    {
      services.kanidm.provision.systems.oauth2.oauth2-proxy =
        let
          domain = environment.getDomainFor "oauth2-proxy";
        in
        {
          displayName = "OAuth2-Proxy";
          originUrl = "https://${domain}/oauth2/callback";
          originLanding = "https://${domain}/";
          basicSecretFile = config.age.secrets.oauth2-proxy-oidc-client-secret.path;
          preferShortUsername = true;
          scopeMaps = {
            "media.access" = [
              "openid"
              "email"
              "profile"
              "groups"
            ];
            "media.admins" = [
              "openid"
              "email"
              "profile"
              "groups"
            ];
            "admins" = [
              "openid"
              "email"
              "profile"
              "groups"
            ];
          };
        };
    };
}
