{
  features.kanidm.linux =
    {
      config,
      secrets,
      environment,
      ...
    }:
    {
      services.kanidm.provision.systems.oauth2.longhorn =
        let
          domain = environment.getDomainFor "longhorn";
        in
        {
          displayName = "longhorn";
          originUrl = [
            "https://${domain}/oauth2/callback"
          ];
          originLanding = "https://${domain}/";
          basicSecretFile = secrets.longhorn-oidc-client-secret;
          scopeMaps."admins" = [
            "openid"
            "email"
            "profile"
          ];
        };
    };
}
