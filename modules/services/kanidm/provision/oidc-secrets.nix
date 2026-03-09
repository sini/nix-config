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
                file,
                ...
              }:
              ''
                # Generate an rfc3986 secret
                secret=$(${pkgs.openssl}/bin/openssl rand -base64 54 | tr -d '\n' | tr '+/' '-_' | tr -d '=' | cut -c1-72)

                # Generate SOPS-encrypted YAML file for Kubernetes use
                # Encrypt directly via stdin so unencrypted content never touches filesystem
                target_path=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".enc.yaml")}
                echo "${name}-oidc-client-secret: $secret" | ${pkgs.sops}/bin/sops \
                  --config ${lib.escapeShellArg "${rootPath}/.sops.yaml"} \
                  --filename-override "$target_path" \
                  --input-type yaml \
                  --output-type yaml \
                  -e /dev/stdin > "$target_path"

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
