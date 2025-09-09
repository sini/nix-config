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
            };

            security = {
              admin_user = "admin";
              secret_key = "$__file{${config.age.secrets.grafana-oidc-secret-grafana.path}}";
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
              client_id = "grafana";
              client_secret = "$__file{${config.age.secrets.grafana-oidc-secret.path}}";
              scopes = "openid profile email groups";
              auth_url = "https://idm.${config.networking.domain}/ui/oauth2";
              token_url = "https://idm.${config.networking.domain}/oauth2/token";
              api_url = "https://idm.${config.networking.domain}/oauth2/openid/grafana/userinfo";
              allow_sign_up = true;
              auto_login = false;
              team_ids = "";
              allowed_organizations = "";
              role_attribute_path = "contains(groups[*], 'grafana_admin') && 'Admin' || contains(groups[*], 'grafana_editor') && 'Editor' || 'Viewer'";
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
                orgId = 1;
                folder = "";
                type = "file";
                disableDeletion = false;
                updateIntervalSeconds = 10;
                options.path = "/etc/grafana/dashboards";
              }
            ];
          };
        };

        nginx.virtualHosts = {
          "grafana.${config.networking.domain}" = {
            forceSSL = true;
            useACMEHost = config.networking.domain;
            locations."/" = {
              proxyPass = "http://127.0.0.1:3000";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
          };
        };
      };

      # Create dashboards directory and populate with basic dashboards
      environment.etc = {
        "grafana/dashboards/node-exporter.json" = {
          source = pkgs.writeText "node-exporter-dashboard.json" (
            builtins.toJSON {
              dashboard = {
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
              };
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
