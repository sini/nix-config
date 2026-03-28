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
        systems.oauth2.forgejo =
          let
            domain = environment.getDomainFor "forgejo";
          in
          {
            displayName = "Forgejo";
            originUrl = "https://${domain}/user/oauth2/kanidm/callback";
            originLanding = "https://${domain}/";
            basicSecretFile = secrets.forgejo-oidc-client-secret;
            scopeMaps."forgejo.access" = [
              "openid"
              "email"
              "profile"
            ];
            # XXX: PKCE is currently not supported by gitea/forgejo,
            # see https://github.com/go-gitea/gitea/issues/21376.
            allowInsecureClientDisablePkce = true;
            preferShortUsername = true;
            claimMaps.groups = {
              joinType = "array";
              valuesByGroup."forgejo.admins" = [ "admin" ];
            };
          };
      };
    };
}
