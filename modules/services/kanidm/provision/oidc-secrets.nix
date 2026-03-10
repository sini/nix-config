{ rootPath, ... }:
{
  flake.features.kanidm.nixos =
    {
      config,
      environment,
      lib,
      ...
    }:
    let
      mkOidcSecrets = name: {
        "${name}-oidc-client-secret" = {
          rekeyFile = rootPath + "/.secrets/env/${environment.name}/oidc/${name}-oidc-client-secret.age";
          owner = "kanidm";
          group = "kanidm";
          generator = {
            tags = [ "oidc" ];
            script =
              {
                pkgs,
                ...
              }:
              ''
                # Generate an rfc3986 secret
                secret=$(${pkgs.openssl}/bin/openssl rand -base64 54 | tr -d '\n' | tr '+/' '-_' | tr -d '=' | cut -c1-72)
                echo "$secret"
              '';
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
