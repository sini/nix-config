{
  flake.features.kanidm.linux =
    {
      config,
      environment,
      ...
    }:
    {
      services.kanidm.provision = {
        groups = {
          "vpn.users".members = [ "admins" ];
        };

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
            basicSecretFile = config.age.secrets.headscale-oidc-client-secret.path;
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
