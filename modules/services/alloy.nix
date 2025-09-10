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
          }
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
