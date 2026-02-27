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
          # If we switch to a service that only requires hashes like authelia, we can make this intermediate
          # intermediary = true;
          generator = {
            tags = [ "oidc" ];
            script =
              { pkgs, file, ... }:
              ''
                # Generate an rfc3986 secret
                secret=$(${pkgs.openssl}/bin/openssl rand -base64 54 | tr -d '\n' | tr '+/' '-_' | tr -d '=' | cut -c1-72)

                # Generate a pbkdf2 hash, and store in plaintext file
                hashed=$(echo $secret | ${pkgs.python3}/bin/python3 -c "
                import hashlib, base64, os, sys
                input = sys.stdin.readlines()[0].strip()
                base64_adapted_alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789./'
                def encode_base64_adapted(data):
                    base64_encoded = base64.b64encode(data).decode('utf-8').strip('=')
                    return base64_encoded.translate(str.maketrans('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', base64_adapted_alphabet))
                salt = os.urandom(16)
                key = hashlib.pbkdf2_hmac('sha512', input.encode(), salt, 310000, 64)
                salt_b64 = encode_base64_adapted(salt)
                key_b64 = encode_base64_adapted(key)
                print(f'\$pbkdf2-sha512\''${310000}\''${salt_b64}\''${key_b64}')")

                echo "$hashed" > ${lib.escapeShellArg (lib.removeSuffix "-secret.age" file + "-hash")}

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

      envoyOidcConfigFor =
        {
          name,
          accessGroups ? [ "admins" ],
        }:
        {
          displayName = name;
          originUrl = [
            "https://${name}.${environment.domain}/oauth2/callback"
          ];
          originLanding = "https://${name}.${environment.domain}/";
          basicSecretFile = config.age.secrets."${name}-oidc-client-secret".path;
          scopeMaps = lib.genAttrs accessGroups (_group: [
            "openid"
            "email"
            "profile"
          ]);
          preferShortUsername = true;
        };
    in
    {
      age.secrets = lib.mkMerge (
        map mkOidcSecrets [
          # Nix services
          "grafana"
          "jellyfin"
          "oauth2-proxy"
          "open-webui"
          "headscale"
          # Envoy OIDC services
          "hubble"
        ]
      );

      services.kanidm.provision = {
        persons = {
          json = {
            displayName = "Jason";
            mailAddresses = [ "jason@${environment.email.domain}" ];
          };
          shuo = {
            displayName = "Shuo";
            mailAddresses = [ "shuo@${environment.email.domain}" ];
          };
          will = {
            displayName = "Will";
            mailAddresses = [ "will@${environment.email.domain}" ];
          };
          greco = {
            displayName = "Jason";
            mailAddresses = [ "greco@${environment.email.domain}" ];
          };
          taiche = {
            displayName = "Chris";
            mailAddresses = [ "taiche@${environment.email.domain}" ];
          };
          jennism = {
            displayName = "Jennifer";
            mailAddresses = [ "jennism@${environment.email.domain}" ];
          };
          hugs = {
            displayName = "Shawn";
            mailAddresses = [ "hugs@${environment.email.domain}" ];
          };
          ellen = {
            displayName = "Ellen";
            mailAddresses = [ "ellen@${environment.email.domain}" ];
          };
          jenn = {
            displayName = "Jennifer";
            mailAddresses = [ "jenn@${environment.email.domain}" ];
          };
          tyr = {
            displayName = "tyr";
            mailAddresses = [ "tyr@${environment.email.domain}" ];
          };
          zogger = {
            displayName = "zogger";
            mailAddresses = [ "zogger@${environment.email.domain}" ];
          };
          jess = {
            displayName = "jess";
            mailAddresses = [ "jess@${environment.email.domain}" ];
          };
          leo = {
            displayName = "leo";
            mailAddresses = [ "leo@${environment.email.domain}" ];
          };
          vincentpierre = {
            displayName = "vincentpierre";
            mailAddresses = [ "vincentpierre@${environment.email.domain}" ];
          };
          you = {
            displayName = "You";
            mailAddresses = [ "you@${environment.email.domain}" ];
          };
          yiran = {
            displayName = "Yiran";
            mailAddresses = [ "yiran@${environment.email.domain}" ];
          };
          louisabella = {
            displayName = "louisabella";
            mailAddresses = [ "louisabella@${environment.email.domain}" ];
          };
        };

        # OAuth2 clients and groups for services
        groups = {
          "admins".members = [
            "json"
            "shuo"
          ];

          "users" = { };

          "grafana.access".members = [
            "json"
            "shuo"
            "will"
            "hugs"
          ];

          "grafana.editors" = { };
          "grafana.admins" = { };
          "grafana.server-admins".members = [
            "json"
            "shuo"
            "will"
            "hugs"
          ];

          "open-webui.access".members = [
            "json"
            "shuo"
            "will"
            "greco"
            "hugs"
          ];

          "open-webui.admins".members = [
            "admins"
          ];

          "media.access".members = [
            "users"
          ];

          "media.admins".members = [
            "admins"
          ];

          "vpn.users".members = [
            "admins"
          ];
        };

        systems.oauth2 = {
          grafana = {
            displayName = "Grafana Dashboard";
            originLanding = "https://grafana.${environment.domain}/login/generic_oauth";
            originUrl = "https://grafana.${environment.domain}";
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

          headscale = {
            displayName = "vpn";
            originUrl = [
              "https://hs.${environment.domain}/oidc/callback"
              "https://hs.${environment.domain}/admin/oidc/callback"
            ];
            originLanding = "https://hs.${environment.domain}/admin";
            basicSecretFile = config.age.secrets.headscale-oidc-client-secret.path;
            scopeMaps."vpn.users" = [
              "openid"
              "email"
              "profile"
            ];
            preferShortUsername = true;
          };

          hubble = envoyOidcConfigFor { name = "hubble"; };

          kubernetes = {
            displayName = "kubernetes";
            originUrl = "http://localhost:8000";
            originLanding = "http://localhost:8000";
            # basicSecretFile = config.age.secrets.kubernetes-oidc-client-secret.path;
            public = true;
            enableLocalhostRedirects = true;
            scopeMaps."admins" = [
              "openid"
              "email"
              "profile"
              "groups"
            ];
            preferShortUsername = true;
          };

          open-webui = {
            displayName = "open-webui";
            imageFile = builtins.path { path = rootPath + /assets/open-webui.svg; };
            originUrl = "https://open-webui.${environment.domain}/oauth/oidc/callback";
            originLanding = "https://open-webui.${environment.domain}/auth";
            basicSecretFile = config.age.secrets.open-webui-oidc-client-secret.path;
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

          jellyfin = {
            displayName = "Jellyfin";
            originUrl = "https://jellyfin.${environment.domain}/sso/OID/redirect/kanidm";
            originLanding = "https://jellyfin.${environment.domain}";
            basicSecretFile = config.age.secrets.jellyfin-oidc-client-secret.path;
            preferShortUsername = true;
            scopeMaps = {
              "media.access" = [
                "openid"
                "profile"
                "groups"
              ];
              "media.admins" = [
                "openid"
                "profile"
                "groups"
              ];
            };
            claimMaps.roles = {
              joinType = "array";
              valuesByGroup = {
                "media.admins" = [
                  "admin"
                  "user"
                ];
                "media.access" = [ "user" ];
              };
            };
          };

          oauth2-proxy = {
            displayName = "OAuth2-Proxy";
            originUrl = "https://oauth2-proxy.${environment.domain}/oauth2/callback";
            originLanding = "https://oauth2-proxy.${environment.domain}/";
            basicSecretFile = config.age.secrets.oauth2-proxy-oidc-client-secret.path;
            preferShortUsername = true;
            scopeMaps = {
              "media.access" = [
                "openid"
                "email"
                "profile"
                "groups"
              ];
              "media.admins" = [
                "openid"
                "email"
                "profile"
                "groups"
              ];
              "admins" = [
                "openid"
                "email"
                "profile"
                "groups"
              ];
            };
          };
        };
      };
    };
}
