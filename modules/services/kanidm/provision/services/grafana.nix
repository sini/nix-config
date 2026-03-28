{
  features.kanidm.linux =
    {
      secrets,
      environment,
      ...
    }:
    {
      services.kanidm.provision = {
        systems.oauth2.grafana =
          let
            domain = environment.getDomainFor "grafana";
          in
          {
            displayName = "Grafana Dashboard";
            originLanding = "https://${domain}/login/generic_oauth";
            originUrl = "https://${domain}";
            basicSecretFile = secrets.grafana-oidc-client-secret;
            scopeMaps."grafana.access" = [
              "openid"
              "email"
              "profile"
            ];
            claimMaps.groups = {
              joinType = "array";
              valuesByGroup = {
                "grafana.editors" = [ "editor" ];
                "grafana.admins" = [ "admin" ];
                "grafana.server-admins" = [ "server_admin" ];
              };
            };
            allowInsecureClientDisablePkce = false;
            preferShortUsername = true;
          };
      };
    };
}
