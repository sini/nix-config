{
  config,
  lib,
  ...
}:
let
  # Find the first host with the metrics-ingester role
  lokiHost = lib.head (
    lib.mapAttrsToList (hostname: hostConfig: hostConfig.ipv4) (
      lib.attrsets.filterAttrs (
        hostname: hostConfig: builtins.elem "metrics-ingester" hostConfig.roles
      ) config.flake.hosts
    )
  );
in
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
              url = "http://${lokiHost}:3100/loki/api/v1/push";
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
          ];
        };
      };

      # Create promtail positions directory
      systemd.tmpfiles.rules = [
        "d /var/lib/promtail 0755 promtail promtail -"
      ];
    };
}
