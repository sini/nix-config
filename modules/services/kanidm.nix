{ rootPath, ... }:
{
  flake.modules.nixos.kanidm =
    {
      config,
      pkgs,
      environment,
      ...
    }:
    {
      age.secrets.kanidm-admin-password = {
        rekeyFile = rootPath + "/.secrets/services/kanidm-admin-password.age";
        owner = "kanidm";
        group = "kanidm";
      };

      age.secrets.grafana-oidc-secret = {
        rekeyFile = rootPath + "/.secrets/services/grafana-oidc-secret.age";
        owner = "kanidm";
        group = "kanidm";
      };

      services = {
        kanidm = {
          enableServer = true;
          enableClient = true;
          package = pkgs.kanidm_1_7.withSecretProvisioning;

          serverSettings = {
            domain = config.networking.domain;
            origin = "https://idm.${config.networking.domain}";
            bindaddress = "127.0.0.1:8443";
            ldapbindaddress = "127.0.0.1:3636";
            trust_x_forward_for = true;

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
            };

            # OAuth2 clients and groups for services
            groups = {
              "grafana.access" = {
                members = [
                  "json"
                  "shuo"
                  "will"
                  "hugs"
                ];
              };
              "grafana.editors" = { };
              "grafana.admins" = { };
              "grafana.server-admins" = {
                members = [
                  "json"
                  "shuo"
                  "will"
                  "hugs"
                ];
              };
            };

            systems.oauth2 = {
              grafana = {
                displayName = "Grafana Dashboard";
                originLanding = "https://grafana.${config.networking.domain}/login/generic_oauth";
                originUrl = "https://grafana.${config.networking.domain}";
                basicSecretFile = config.age.secrets.grafana-oidc-secret.path;
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

      # Grant kanidm access to certificates
      users.users.kanidm.extraGroups = [
        config.security.acme.defaults.group
        config.services.nginx.group
      ];
    };
}
