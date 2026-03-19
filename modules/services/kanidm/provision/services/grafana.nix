{
  features.kanidm.linux =
    {
      config,
      environment,
      ...
    }:
    {
      services.kanidm.provision = {
        groups = {
          "grafana.access".members = [ "users" ];
          "grafana.editors".members = [ ];
          "grafana.admins".members = [ ];
          "grafana.server-admins".members = [ "admins" ];
        };

        systems.oauth2.grafana =
          let
            domain = environment.getDomainFor "grafana";
          in
          {
            displayName = "Grafana Dashboard";
            originLanding = "https://${domain}/login/generic_oauth";
            originUrl = "https://${domain}";
            basicSecretFile = config.age.secrets.grafana-oidc-client-secret.path;
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
