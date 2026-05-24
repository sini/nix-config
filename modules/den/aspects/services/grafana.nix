# Grafana — dashboards + OIDC via Kanidm, Prometheus + Loki datasources,
# SQLite backend, role-based access through group mapping.
#
# Ported from main:modules/services/monitoring/grafana/grafana.nix
{
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.services.grafana = {
    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        env = environments.${host.environment};
        domain = env.getDomainFor "grafana";
        kanidmDomain = env.getDomainFor "kanidm";
      in
      {
        services = {
          grafana = {
            enable = true;
            settings = {
              server = {
                inherit domain;
                http_addr = "127.0.0.1";
                http_port = 3000;
                root_url = "https://${domain}";
                enforce_domain = false;
              };

              security = {
                disable_initial_admin_creation = true;
                cookie_secure = true;
                disable_gravatar = true;
                hide_version = true;
                secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
              };

              database = {
                type = "sqlite3";
                path = "/var/lib/grafana/grafana.db";
              };

              analytics = {
                reporting_enabled = false;
                check_for_updates = false;
              };

              users = {
                allow_sign_up = false;
                auto_assign_org = true;
                auto_assign_org_role = "Viewer";
              };

              auth = {
                disable_login_form = false;
                oauth_auto_login = true;
              };

              "auth.generic_oauth" = {
                enabled = true;
                name = "KanIDM";
                icon = "signin";
                allow_sign_up = true;
                auto_login = true;
                client_id = "grafana";
                client_secret = "$__file{${config.age.secrets.grafana-oidc-secret.path}}";
                scopes = "openid email profile";
                login_attribute_path = "preferred_username";
                auth_url = "https://${kanidmDomain}/ui/oauth2";
                token_url = "https://${kanidmDomain}/oauth2/token";
                api_url = "https://${kanidmDomain}/oauth2/openid/grafana/userinfo";
                use_pkce = true;
                use_refresh_token = true;
                role_attribute_path = "contains(groups[*], 'server_admin') && 'GrafanaAdmin' || contains(groups[*], 'admin') && 'Admin' || contains(groups[*], 'editor') && 'Editor' || 'Viewer'";
                role_attribute_strict = false;
                allow_assign_grafana_admin = true;
                skip_org_role_sync = false;
              };
            };

            provision = {
              enable = true;
              datasources.settings.datasources = [
                {
                  name = "Prometheus";
                  type = "prometheus";
                  access = "proxy";
                  url = "http://127.0.0.1:9090";
                  isDefault = true;
                  jsonData = {
                    timeInterval = "5s";
                    httpMethod = "POST";
                  };
                }
                {
                  name = "Loki";
                  type = "loki";
                  access = "proxy";
                  url = "http://127.0.0.1:3100";
                  jsonData = {
                    maxLines = 1000;
                  };
                }
              ];

              dashboards.settings.providers = [
                {
                  name = "default";
                  options.path = pkgs.stdenv.mkDerivation {
                    name = "grafana-dashboards";
                    src = ./grafana-dashboards;
                    installPhase = ''
                      mkdir -p $out/
                      install -D -m755 $src/*.json $out/
                    '';
                  };
                }
              ];
            };
          };

          nginx.virtualHosts."${domain}" = {
            forceSSL = true;
            useACMEHost = env.domain;
            locations."/" = {
              proxyPass = "http://127.0.0.1:3000";
              proxyWebsockets = true;
            };
          };
        };

        # Ensure grafana user can read secret files
        systemd.services.grafana.serviceConfig = {
          SupplementaryGroups = [ "keys" ];
        };
      };

    age-secrets =
      { host, ... }:
      let
        env = environments.${host.environment};
      in
      {
        age.secrets = {
          grafana-oidc-secret = {
            rekeyFile = env.secretPath + "/oidc/grafana-oidc-client-secret.age";
            owner = "grafana";
            group = "grafana";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
          };

          grafana-secret-key = {
            rekeyFile = env.secretPath + "/grafana-secret-key.age";
            settings.length = "32";
            generator.script = "hex";
            owner = "grafana";
            group = "grafana";
          };
        };
      };

    service-domains = [ "grafana" ];

    persist = {
      directories = [
        {
          directory = "/var/lib/grafana";
          user = "grafana";
          group = "grafana";
          mode = "0700";
        }
      ];
    };
  };
}
