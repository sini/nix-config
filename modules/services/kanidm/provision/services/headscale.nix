{
  features.kanidm.linux =
    {
      config,
      secrets,
      environment,
      ...
    }:
    {
      services.kanidm.provision = {
        systems.oauth2.headscale =
          let
            domain = environment.getDomainFor "headscale";
          in
          {
            displayName = "vpn";
            originUrl = [
              "https://${domain}/oidc/callback"
              "https://${domain}/admin/oidc/callback"
            ];
            originLanding = "https://${domain}/admin";
            basicSecretFile = secrets.headscale-oidc-client-secret;
            scopeMaps."vpn.users" = [
              "openid"
              "email"
              "profile"
            ];
            preferShortUsername = true;
          };
      };
    };
}
