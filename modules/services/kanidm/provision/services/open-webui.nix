{ rootPath, ... }:
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
        systems.oauth2.open-webui =
          let
            domain = environment.getDomainFor "open-webui";
          in
          {
            displayName = "open-webui";
            imageFile = builtins.path { path = rootPath + /assets/open-webui.svg; };
            originUrl = "https://${domain}/oauth/oidc/callback";
            originLanding = "https://${domain}/auth";
            basicSecretFile = secrets.open-webui-oidc-client-secret;
            scopeMaps."open-webui.access" = [
              "openid"
              "email"
              "profile"
            ];
            preferShortUsername = true;
            claimMaps = {
              groups = {
                joinType = "array";
                valuesByGroup."open-webui.admins" = [ "admins" ];
              };
              roles = {
                joinType = "array";
                valuesByGroup = {
                  "open-webui.admins" = [ "admin" ];
                  "open-webui.access" = [ "user" ];
                };
              };
            };
          };
      };
    };
}
