{
  flake.features.kanidm.nixos =
    {
      config,
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
          basicSecretFile = config.age.secrets.hubble-ui-oidc-client-secret.path;
          scopeMaps."admins" = [
            "openid"
            "email"
            "profile"
          ];
        };
    };
}
