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
            disable = true; # No server needed for log collection agents
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
              pipeline_stages = [
                {
                  json.expressions = {
                    transport = "_TRANSPORT";
                    unit = "_SYSTEMD_UNIT";
                    msg = "MESSAGE";
                    coredump_cgroup = "COREDUMP_CGROUP";
                    coredump_exe = "COREDUMP_EXE";
                    coredump_cmdline = "COREDUMP_CMDLINE";
                    coredump_uid = "COREDUMP_UID";
                    coredump_gid = "COREDUMP_GID";
                  };
                }
                {
                  # Set the unit (defaulting to the transport like audit and kernel)
                  template = {
                    source = "unit";
                    template = "{{if .unit}}{{.unit}}{{else}}{{.transport}}{{end}}";
                  };
                }
                {
                  regex = {
                    expression = "(?P<coredump_unit>[^/]+)$";
                    source = "coredump_cgroup";
                  };
                }
                {
                  template = {
                    source = "msg";
                    template = "{{if .coredump_exe}}{{.coredump_exe}} core dumped (user: {{.coredump_uid}}/{{.coredump_gid}}, command: {{.coredump_cmdline}}){{else}}{{.msg}}{{end}}";
                  };
                }
                {
                  labels.coredump_unit = "coredump_unit";
                }
                {
                  # Normalize session IDs (session-1234.scope -> session.scope) to limit number of label values
                  replace = {
                    source = "unit";
                    expression = "^(session-\\d+.scope)$";
                    replace = "session.scope";
                  };
                }
                {
                  labels.unit = "unit";
                }
                {
                  # Write the proper message instead of JSON
                  output.source = "msg";
                }
              ];
              relabel_configs = [
                {
                  source_labels = [ "__journal__hostname" ];
                  target_label = "host";
                }
                {
                  source_labels = [ "__journal_priority" ];
                  target_label = "priority";
                }
                {
                  source_labels = [ "__journal_priority_keyword" ];
                  target_label = "level";
                }
                {
                  source_labels = [ "__journal__systemd_unit" ];
                  target_label = "unit";
                }
                {
                  source_labels = [ "__journal__systemd_user_unit" ];
                  target_label = "user_unit";
                }
                {
                  source_labels = [ "__journal__boot_id" ];
                  target_label = "boot_id";
                }
                {
                  source_labels = [ "__journal__comm" ];
                  target_label = "command";
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
