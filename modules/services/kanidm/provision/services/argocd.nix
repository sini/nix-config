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
          "argocd.access".members = [ "users" ];
          "argocd.admins".members = [ "admins" ];
        };

        systems.oauth2.argocd =
          let
            domain = environment.getDomainFor "argocd";
          in
          {
            displayName = "argocd";
            originUrl = [
              "https://${domain}/auth/callback"
            ];
            originLanding = "https://${domain}/applications";
            basicSecretFile = config.age.secrets.argocd-oidc-client-secret.path;
            preferShortUsername = true;

            scopeMaps = {
              "argocd.access" = [
                "openid"
                "email"
                "profile"
              ];
            };
            claimMaps.groups = {
              joinType = "array";
              valuesByGroup = {
                "argocd.admins" = [ "admin" ];
                "argocd.access" = [ "user" ];
              };
            };
          };
      };
    };
}
