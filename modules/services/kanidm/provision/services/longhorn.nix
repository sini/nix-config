{
  features.kanidm.linux =
    {
      config,
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
          basicSecretFile = config.age.secrets.longhorn-oidc-client-secret.path;
          scopeMaps."admins" = [
            "openid"
            "email"
            "profile"
          ];
        };
    };
}
