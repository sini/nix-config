{
  flake.features.kanidm.linux =
    {
      config,
      environment,
      lib,
      ...
    }:
    let
      mkOidcSecrets = name: {
        "${name}-oidc-client-secret" = {
          rekeyFile = environment.secretPath + "/oidc/${name}-oidc-client-secret.age";
          owner = "kanidm";
          group = "kanidm";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
        };
      };
    in
    {
      age.secrets = lib.mkMerge (
        map mkOidcSecrets (
          builtins.attrNames (
            lib.filterAttrs (
              _name: system: !(system.public or false)
            ) config.services.kanidm.provision.systems.oauth2
          )
        )
      );
    };
}
