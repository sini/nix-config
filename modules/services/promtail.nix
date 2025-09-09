# { rootPath, ... }:
{
  flake.modules.nixos.promtail =
    { config, ... }:
    {
      services.promtail = {
        enable = true;
        configuration = {
          server = {
            http_listen_address = "127.0.0.1";
            http_listen_port = 9080;
          };

          positions = {
            filename = "/var/lib/promtail/positions.yaml";
          };

          clients = [
            {
              url = "http://127.0.0.1:3100/loki/api/v1/push";
            }
          ];

          scrape_configs = [
            {
              job_name = "journal";
              journal = {
                max_age = "12h";
                labels = {
                  job = "systemd-journal";
                  host = config.networking.hostName;
                };
              };
              relabel_configs = [
                {
                  source_labels = [ "__journal__systemd_unit" ];
                  target_label = "unit";
                }
                {
                  source_labels = [ "__journal_priority" ];
                  target_label = "priority";
                }
                {
                  source_labels = [ "__journal__hostname" ];
                  target_label = "hostname";
                }
              ];
            }
            {
              job_name = "nginx-access";
              static_configs = [
                {
                  targets = [ "localhost" ];
                  labels = {
                    job = "nginx-access";
                    host = config.networking.hostName;
                    __path__ = "/var/log/nginx/access.log";
                  };
                }
              ];
              pipeline_stages = [
                {
                  regex = {
                    expression = "^(?P<remote_addr>[\\w\\.]+) - (?P<remote_user>\\S+) \\[(?P<time_local>[\\w:/]+\\s[+\\-]\\d{4})\\] \"(?P<method>\\S+) (?P<request>\\S+) (?P<protocol>\\S+)\" (?P<status>\\d{3}) (?P<body_bytes_sent>\\d+) \"(?P<http_referer>[^\"]*)\" \"(?P<http_user_agent>[^\"]*)\"";
                  };
                }
                {
                  labels = {
                    method = "";
                    status = "";
                    remote_addr = "";
                  };
                }
              ];
            }
            {
              job_name = "nginx-error";
              static_configs = [
                {
                  targets = [ "localhost" ];
                  labels = {
                    job = "nginx-error";
                    host = config.networking.hostName;
                    __path__ = "/var/log/nginx/error.log";
                  };
                }
              ];
            }
          ];
        };
      };

      # Ensure promtail can read nginx logs
      users.users.promtail.extraGroups = [ "nginx" ];

      # Create promtail positions directory
      systemd.tmpfiles.rules = [
        "d /var/lib/promtail 0755 promtail promtail -"
      ];

      # Configure log rotation for nginx to ensure promtail can track rotated logs
      services.logrotate.settings.nginx = {
        files = "/var/log/nginx/*.log";
        frequency = "daily";
        rotate = 30;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        create = "644 nginx nginx";
        postrotate = "systemctl reload nginx";
      };
    };
}
