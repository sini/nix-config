{
  features.kanidm.linux =
    {
      config,
      secrets,
      environment,
      ...
    }:
    {
      services.kanidm.provision.systems.oauth2.hubble-ui =
        let
          domain = environment.getDomainFor "hubble-ui";
        in
        {
          displayName = "hubble-ui";
          originUrl = [
            "https://${domain}/oauth2/callback"
          ];
          originLanding = "https://${domain}/";
          basicSecretFile = secrets.hubble-ui-oidc-client-secret;
          scopeMaps."admins" = [
            "openid"
            "email"
            "profile"
          ];
        };
    };
}
