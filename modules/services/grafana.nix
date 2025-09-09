{ rootPath, ... }:
{
  flake.modules.nixos.grafana =
    { config, pkgs, ... }:
    {
      age.secrets.grafana-oidc-secret-grafana = {
        rekeyFile = rootPath + "/.secrets/services/grafana-oidc-secret.age";
        owner = "grafana";
        group = "grafana";
      };

      services = {
        grafana = {
          enable = true;
          settings = {
            server = {
              domain = "grafana.${config.networking.domain}";
              http_addr = "127.0.0.1";
              http_port = 3000;
              root_url = "https://grafana.${config.networking.domain}";
              enforce_domain = false;
            };

            security = {
              disable_initial_admin_creation = true;
              cookie_secure = true;
              disable_gravatar = true;
              hide_version = true;
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
              client_secret = "$__file{${config.age.secrets.grafana-oidc-secret-grafana.path}}";
              scopes = "openid email profile";
              login_attribute_path = "preferred_username";
              auth_url = "https://idm.${config.networking.domain}/ui/oauth2";
              token_url = "https://idm.${config.networking.domain}/oauth2/token";
              api_url = "https://idm.${config.networking.domain}/oauth2/openid/grafana/userinfo";
              use_pkce = true;
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
              # {
              #   name = "Loki";
              #   type = "loki";
              #   access = "proxy";
              #   url = "http://127.0.0.1:3100";
              #   jsonData = {
              #     maxLines = 1000;
              #   };
              # }
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

        nginx.virtualHosts."grafana.${config.networking.domain}" = {
          forceSSL = true;
          useACMEHost = config.networking.domain;
          locations."/" = {
            proxyPass = "http://127.0.0.1:3000";
            proxyWebsockets = true;
          };
        };
      };

      # Create dashboards directory and populate with basic dashboards
      environment.etc = {
        "grafana/dashboards/node-exporter.json" = {
          source = pkgs.writeText "node-exporter-dashboard.json" (
            builtins.toJSON {
              id = null;
              title = "Node Exporter Full";
              tags = [
                "prometheus"
                "node-exporter"
              ];
              timezone = "browser";
              panels = [
                {
                  id = 1;
                  title = "CPU Usage";
                  type = "stat";
                  targets = [
                    {
                      expr = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
                      refId = "A";
                    }
                  ];
                  fieldConfig = {
                    defaults = {
                      unit = "percent";
                      thresholds = {
                        steps = [
                          {
                            color = "green";
                            value = null;
                          }
                          {
                            color = "yellow";
                            value = 70;
                          }
                          {
                            color = "red";
                            value = 90;
                          }
                        ];
                      };
                    };
                  };
                  gridPos = {
                    h = 8;
                    w = 12;
                    x = 0;
                    y = 0;
                  };
                }
                {
                  id = 2;
                  title = "Memory Usage";
                  type = "stat";
                  targets = [
                    {
                      expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
                      refId = "A";
                    }
                  ];
                  fieldConfig = {
                    defaults = {
                      unit = "percent";
                      thresholds = {
                        steps = [
                          {
                            color = "green";
                            value = null;
                          }
                          {
                            color = "yellow";
                            value = 70;
                          }
                          {
                            color = "red";
                            value = 90;
                          }
                        ];
                      };
                    };
                  };
                  gridPos = {
                    h = 8;
                    w = 12;
                    x = 12;
                    y = 0;
                  };
                }
                {
                  id = 3;
                  title = "Disk Usage";
                  type = "stat";
                  targets = [
                    {
                      expr = "(1 - (node_filesystem_avail_bytes{fstype!=\"tmpfs\"} / node_filesystem_size_bytes{fstype!=\"tmpfs\"})) * 100";
                      refId = "A";
                    }
                  ];
                  fieldConfig = {
                    defaults = {
                      unit = "percent";
                      thresholds = {
                        steps = [
                          {
                            color = "green";
                            value = null;
                          }
                          {
                            color = "yellow";
                            value = 80;
                          }
                          {
                            color = "red";
                            value = 95;
                          }
                        ];
                      };
                    };
                  };
                  gridPos = {
                    h = 8;
                    w = 24;
                    x = 0;
                    y = 8;
                  };
                }
              ];
              time = {
                from = "now-1h";
                to = "now";
              };
              refresh = "30s";
            }
          );
        };
      };

      # Ensure grafana user can read the password file
      systemd.services.grafana.serviceConfig = {
        SupplementaryGroups = [ "keys" ];
      };
    };
}
