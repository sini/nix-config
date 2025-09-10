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
  flake.modules.nixos.alloy =
    { pkgs, ... }:
    let
      alloyConfigText = ''
        // Loki write endpoint
        loki.write "loki_endpoint" {
          endpoint {
            url = "http://${lokiHost}:3100/loki/api/v1/push"
          }
        }

        // Journal log source
        loki.source.journal "systemd_journal" {
          max_age        = "12h"
          relabel_rules  = loki.relabel.journal_labels.rules
          forward_to     = [loki.process.journal_pipeline.receiver]

          labels = {
            job  = "systemd-journal",
            host = env("HOSTNAME"),
          }
        }

        // Relabel journal fields
        loki.relabel "journal_labels" {
          forward_to = [loki.process.journal_pipeline.receiver]
          
          rule {
            source_labels = ["__journal__hostname"]
            target_label  = "host"
          }

          rule {
            source_labels = ["__journal_priority"]
            target_label  = "priority"
          }

          rule {
            source_labels = ["__journal_priority_keyword"]
            target_label  = "level"
          }

          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }

          rule {
            source_labels = ["__journal__systemd_user_unit"]
            target_label  = "user_unit"
          }

          rule {
            source_labels = ["__journal__boot_id"]
            target_label  = "boot_id"
          }

          rule {
            source_labels = ["__journal__comm"]
            target_label  = "command"
          }
        }

        // Process journal logs with pipeline stages
        loki.process "journal_pipeline" {
          // Extract JSON fields from journal
          stage.json {
            expressions = {
              transport         = "_TRANSPORT",
              unit             = "_SYSTEMD_UNIT",
              msg              = "MESSAGE",
              coredump_cgroup  = "COREDUMP_CGROUP",
              coredump_exe     = "COREDUMP_EXE",
              coredump_cmdline = "COREDUMP_CMDLINE",
              coredump_uid     = "COREDUMP_UID",
              coredump_gid     = "COREDUMP_GID",
            }
          }

          // Set unit label (defaulting to transport for kernel/audit logs)
          stage.template {
            source   = "unit"
            template = "{{if .unit}}{{.unit}}{{else}}{{.transport}}{{end}}"
          }

          // Extract coredump unit name from cgroup path
          stage.regex {
            expression = "(?P<coredump_unit>[^/]+)$"
            source     = "coredump_cgroup"
          }

          // Format coredump messages nicely
          stage.template {
            source   = "message"
            template = "{{if .coredump_exe}}{{.coredump_exe}} core dumped (user: {{.coredump_uid}}/{{.coredump_gid}}, command: {{.coredump_cmdline}}){{else}}{{.msg}}{{end}}"
          }

          // Add coredump unit as label
          stage.labels {
            values = {
              coredump_unit = "coredump_unit",
            }
          }

          // Normalize session IDs to reduce label cardinality
          stage.replace {
            source      = "unit"
            expression  = "^(session-\\d+.scope)$"
            replace     = "session.scope"
          }

          // Set final unit label
          stage.labels {
            values = {
              unit = "unit",
            }
          }

          // Use the processed message as output
          stage.output {
            source = "message"
          }

          forward_to = [loki.write.loki_endpoint.receiver]
        }
      '';

      # Create a package containing the Alloy configuration
      alloyConfigPackage = pkgs.writeTextFile {
        name = "alloy-config";
        text = alloyConfigText;
        destination = "/config.alloy";
      };
    in
    {
      services.alloy = {
        enable = true;
        configPath = alloyConfigPackage;
        extraFlags = [
          "--server.http.listen-addr=127.0.0.1:12345"
          "--disable-reporting"
        ];
      };

      # Create alloy data directories
      systemd.tmpfiles.rules = [
        "d /var/lib/alloy 0755 root root -"
      ];
    };
}
