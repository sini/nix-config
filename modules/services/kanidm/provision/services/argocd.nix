{
  features.kanidm.linux =
    {
      secrets,
      environment,
      ...
    }:
    {
      services.kanidm.provision = {
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
            basicSecretFile = secrets.argocd-oidc-client-secret;
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
