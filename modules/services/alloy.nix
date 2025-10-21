{
  config,
  lib,
  ...
}:
{
  flake.features.alloy.nixos =
    {
      pkgs,
      hostOptions,
      environment,
      ...
    }:
    let
      currentHostEnvironment = hostOptions.environment;

      # Determine target environment for log shipping (check for delegation)
      targetEnvironment =
        if environment.delegation.logsTo != null then
          environment.delegation.logsTo
        else
          currentHostEnvironment;

      # Find the first host with the metrics-ingester role in target environment
      lokiHosts = lib.mapAttrsToList (hostname: hostConfig: builtins.head hostConfig.ipv4) (
        lib.attrsets.filterAttrs (
          hostname: hostConfig:
          builtins.elem "metrics-ingester" hostConfig.roles && hostConfig.environment == targetEnvironment
        ) config.flake.hosts
      );

      lokiHost = if lokiHosts != [ ] then lib.head lokiHosts else null;

      alloyConfigText =
        if lokiHost != null then
          ''
            // Loki write endpoint (delegated to ${targetEnvironment})
            loki.write "loki_endpoint" {
              endpoint {
                url = "http://${lokiHost}:3100/loki/api/v1/push"
              }
            }

            // Relabel journal fields
            loki.relabel "journal_labels" {
              forward_to = [loki.write.loki_endpoint.receiver]

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

            // Journal log source - direct forwarding
            loki.source.journal "systemd_journal" {
              max_age        = "12h"
              relabel_rules  = loki.relabel.journal_labels.rules
              forward_to     = [loki.write.loki_endpoint.receiver]

              labels = {
                job  = "systemd-journal",
                host = env("HOSTNAME"),
                environment = "${currentHostEnvironment}",
                log_source = "${currentHostEnvironment}",
                log_destination = "${targetEnvironment}",
              }
            }
          ''
        else
          ''
            // No Loki endpoint available - logs disabled
            logging {
              level = "warn"
              format = "logfmt"
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
      services.alloy = lib.mkIf (lokiHost != null) {
        enable = true;
        configPath = alloyConfigPackage;
        extraFlags = [
          "--server.http.listen-addr=127.0.0.1:12345"
          "--disable-reporting"
        ];
      };

      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/private/alloy";
          user = "nobody";
          group = "nogroup";
          mode = "0750";
        }
      ];

      # Create alloy data directories
      systemd.tmpfiles.rules = [
        "d /var/lib/alloy 0755 root root -"
      ];
    };
}
