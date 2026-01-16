{ rootPath, ... }:
{
  flake.features.kanidm.nixos =
    {
      config,
      pkgs,
      environment,
      lib,
      ...
    }:
    let
      mkSecret = name: {
        rekeyFile = rootPath + "/.secrets/services/${name}";
        owner = "kanidm";
        group = "kanidm";
      };

      mkOidcSecrets = name: {
        "${name}-oidc-client-secret" = {
          rekeyFile = rootPath + "/.secrets/services/${name}-oidc-client-secret.age";
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
                echo "$secret"
              '';
          };
        };
      };
    in
    {
      age.secrets = lib.mkMerge (
        [
          {
            kanidm-admin-password = mkSecret "kanidm-admin-password.age";
          }
        ]
        ++ map mkOidcSecrets [
          "grafana"
          "jellyfin"
          "kubernetes"
          "oauth2-proxy"
          "open-webui"
        ]
      );

      services = {
        kanidm = {
          enableServer = true;
          enableClient = true;
          package = pkgs.kanidm_1_8.withSecretProvisioning;

          serverSettings = {
            domain = config.networking.domain;
            origin = "https://idm.${config.networking.domain}";
            bindaddress = "127.0.0.1:8443";
            ldapbindaddress = "127.0.0.1:3636";

            # TLS certificates from ACME
            tls_chain = "${config.security.acme.certs.${config.networking.domain}.directory}/fullchain.pem";
            tls_key = "${config.security.acme.certs.${config.networking.domain}.directory}/key.pem";
          };

          clientSettings = {
            uri = "https://idm.${config.networking.domain}";
          };

          provision = {
            enable = true;
            adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
            idmAdminPasswordFile = config.age.secrets.kanidm-admin-password.path;

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
            };

            # OAuth2 clients and groups for services
            groups = {
              "admins".members = [
                "json"
                "shuo"
              ];

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
                "hugs"
              ];

              "open-webui.admins".members = [
                "json"
                "shuo"
              ];

              "media.access".members = [
                "json"
                "shuo"
                "will"
                "hugs"
                "taiche"
                "jennism"
                "ellen"
                "jenn"
                "tyr"
                "zogger"
                "jess"
                "leo"
              ];

              "media.admins" = {
                members = [
                  "json"
                  "shuo"
                ];
              };
            };

            systems.oauth2 = {
              grafana = {
                displayName = "Grafana Dashboard";
                originLanding = "https://grafana.${config.networking.domain}/login/generic_oauth";
                originUrl = "https://grafana.${config.networking.domain}";
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
                originUrl = "https://open-webui.${config.networking.domain}/oauth/oidc/callback";
                originLanding = "https://open-webui.${config.networking.domain}/auth";
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
                originUrl = "https://jellyfin.${config.networking.domain}/sso/OID/redirect/kanidm";
                originLanding = "https://jellyfin.${config.networking.domain}";
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
                originUrl = "https://${config.networking.domain}/oauth2/callback";
                originLanding = "https://${config.networking.domain}/";
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

        nginx.virtualHosts."idm.${config.networking.domain}" = {
          forceSSL = true;
          useACMEHost = config.networking.domain;
          locations."/" = {
            proxyPass = "https://127.0.0.1:8443";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;

              proxy_ssl_server_name on;
              proxy_ssl_name $host;
              proxy_ssl_verify_depth 2;
              proxy_ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
              proxy_ssl_session_reuse off;
            '';
          };
        };
      };

      # Open firewall for LDAP
      networking.firewall.allowedTCPPorts = [ 3636 ];

      # Ensure kanidm user can read the secret files and certificates
      systemd.services.kanidm.serviceConfig = {
        SupplementaryGroups = [ "keys" ];
      };

      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/kanidm";
          user = "kanidm";
          group = "kanidm";
          mode = "0700";
        }
      ];

      # Grant kanidm access to certificates
      users.users.kanidm.extraGroups = [
        config.security.acme.defaults.group
        config.services.nginx.group
      ];
    };
}
