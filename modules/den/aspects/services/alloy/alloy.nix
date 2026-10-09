# Grafana Alloy — every host's push of metrics and logs to the cluster.
#
# The baseline, identical on every host: the systemd journal, plus a
# loopback scrape of each exporter the host announces through the
# prometheus-targets quirk (the aspect that runs an exporter announces it).
# Both are pushed, with basic auth, to the ingest endpoint of the cluster the
# host's environment names (environment.monitoring.ingest), as announced by
# that cluster (monitoring-ingest quirk, kubernetes/services/monitoring/
# ingest.nix). Hosts open no ports for monitoring; with no ingest, Alloy is off.
#
# Label contract (upstream mixins work unmodified):
#   metrics  job = the announced job (node-exporter for the node mixin),
#            instance = den host name, cluster = den environment
#   logs     job = systemd-journal, instance, cluster, unit, level
{ lib, ... }:
let
  credential = "ingest-password";
  ingestFor =
    environment: monitoring-ingest:
    lib.findFirst (i: i.cluster == environment.monitoring.ingest) null monitoring-ingest;
in
{
  den.aspects.services.alloy = {
    nixos =
      {
        config,
        environment,
        host,
        monitoring-ingest,
        prometheus-targets,
        ...
      }:
      let
        ingest = ingestFor environment monitoring-ingest;
        endpoint = path: ''
          endpoint {
            url = "${ingest.url}${path}"
            basic_auth {
              username      = "${ingest.username}"
              password_file = sys.env("CREDENTIALS_DIRECTORY") + "/${credential}"
            }
          }
        '';
        common = ''
          instance = "${host.name}",
          cluster  = "${environment.name}",
        '';
        ownExporters = lib.concatMap (t: t.exporters) (
          lib.filter (t: t.hostname == host.name) prometheus-targets
        );
        scrape = e: ''
          prometheus.scrape "${lib.replaceStrings [ "-" ] [ "_" ] e.job}" {
            job_name   = "${e.job}"
            targets    = [{
              __address__ = "127.0.0.1:${toString e.port}",
              ${common}
            }]
            forward_to = [prometheus.remote_write.ingest.receiver]
          }
        '';
      in
      lib.mkIf (ingest != null) {
        environment.etc."alloy/config.alloy".text = ''
          prometheus.remote_write "ingest" {
            ${endpoint "/api/v1/write"}
          }

          loki.write "ingest" {
            ${endpoint "/loki/api/v1/push"}
          }

          ${lib.concatMapStrings scrape ownExporters}

          loki.relabel "journal" {
            forward_to = []
            rule {
              source_labels = ["__journal__systemd_unit"]
              target_label  = "unit"
            }
            rule {
              source_labels = ["__journal_priority_keyword"]
              target_label  = "level"
            }
          }

          loki.source.journal "journal" {
            relabel_rules = loki.relabel.journal.rules
            labels        = {
              job = "systemd-journal",
              ${common}
            }
            forward_to    = [loki.write.ingest.receiver]
          }
        '';

        services.alloy = {
          enable = true;
          extraFlags = [ "--disable-reporting" ];
        };

        # Shared with the ingest proxy, which holds the derived htpasswd.
        # Declared here rather than as age-secrets so microvm guests get it too.
        # Read by systemd for LoadCredential, so root-owned.
        age.secrets.alloy-ingest-password.rekeyFile = ingest.passwordFile;

        systemd.services.alloy.serviceConfig.LoadCredential =
          "${credential}:${config.age.secrets.alloy-ingest-password.path}";
      };

    # Positions and the remote-write WAL survive restarts and reboots.
    persist.directories = [ "/var/lib/private/alloy" ];
  };
}
