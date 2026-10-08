# Alertmanager outside the cluster — the fleet's notifier of last resort.
#
# Mails the environment's admin address straight through the upstream (not
# the cluster's SMTP relay), so it still works when the cluster is down. The
# host's own Prometheus routes here, and the cluster's Prometheus sends its
# always-firing Watchdog: a timer raises ClusterWatchdogMissing when the
# Watchdog stops arriving, i.e. when the cluster's alerting pipeline is dead.
#
# The API is unauthenticated, so the port is open only to the cluster nodes
# (pod egress to it is masqueraded to the node address).
{ lib, ... }:
let
  port = 9093;
in
{
  den.aspects.services.monitoring.alertmanager = {
    settings.smtp = {
      host = lib.mkOption {
        type = lib.types.str;
        example = "smtp.example.com";
        description = "Upstream submission host (STARTTLS).";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 587;
        description = "Upstream submission port.";
      };
      username = lib.mkOption {
        type = lib.types.str;
        example = "infra@example.com";
        description = "SASL login, also the sender address.";
      };
      passwordSecret = lib.mkOption {
        type = lib.types.str;
        example = "smtp-infra-at-example-com.age";
        description = "Age file with the password or token, relative to the environment's secretPath.";
      };
    };

    # Lets the cluster find this Alertmanager (and the ingester scrape it).
    prometheus-targets =
      { environment, host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit environment;
        exporters = [
          {
            job = "alertmanager";
            inherit port;
          }
        ];
      };

    age-secrets =
      { environment, host, ... }:
      {
        # Read by systemd for LoadCredential, so root-owned.
        age.secrets.alertmanager-smtp-password.rekeyFile =
          environment.secretPath + "/${host.settings.services.monitoring.alertmanager.smtp.passwordSecret}";
      };

    nixos =
      {
        config,
        environment,
        host,
        k3s-nodes,
        pkgs,
        ...
      }:
      let
        inherit (host.settings.services.monitoring.alertmanager) smtp;
        address = builtins.head host.ipv4;
        nodes = lib.unique (
          map (n: n.ip) (lib.filter (n: n.environment.name == host.environment) k3s-nodes)
        );
        api = "http://127.0.0.1:${toString port}/api/v2/alerts";
      in
      {
        services.prometheus.alertmanager = {
          enable = true;
          listenAddress = "0.0.0.0";
          inherit port;
          configuration = {
            global = {
              smtp_smarthost = "${smtp.host}:${toString smtp.port}";
              smtp_from = smtp.username;
              smtp_auth_username = smtp.username;
              smtp_auth_password_file = "/run/credentials/alertmanager.service/smtp-password";
              smtp_require_tls = true;
            };
            route = {
              receiver = "email";
              group_by = [
                "alertname"
                "hostname"
              ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "12h";
              routes = [
                # The cluster's heartbeat: watched by the timer below, never mailed.
                {
                  receiver = "null";
                  matchers = [ ''alertname = "Watchdog"'' ];
                }
              ];
            };
            # A host that is down also fails its own etcd scrape.
            inhibit_rules = [
              {
                source_matchers = [ "alertname = HostDown" ];
                target_matchers = [ "alertname = EtcdMemberDown" ];
                equal = [ "hostname" ];
              }
            ];
            receivers = [
              { name = "null"; }
              {
                name = "email";
                email_configs = [
                  {
                    to = environment.email.adminEmail;
                    send_resolved = true;
                  }
                ];
              }
            ];
          };
        };

        systemd.services.alertmanager.serviceConfig.LoadCredential =
          "smtp-password:${config.age.secrets.alertmanager-smtp-password.path}";

        # Prometheus resends active alerts every minute; a Watchdog older than a
        # few minutes has expired here. While it is missing, keep a
        # ClusterWatchdogMissing alive (10m expiry, refreshed every 2m); once
        # the Watchdog returns it expires and Alertmanager mails "resolved".
        systemd.services.alertmanager-watchdog-check = {
          description = "Raise ClusterWatchdogMissing when the cluster Watchdog stops";
          after = [ "alertmanager.service" ];
          requires = [ "alertmanager.service" ];
          path = [
            pkgs.curl
            pkgs.jq
            pkgs.coreutils
          ];
          serviceConfig = {
            Type = "oneshot";
            DynamicUser = true;
          };
          script = ''
            active=$(curl -fsS --max-time 10 -G ${api} \
              --data-urlencode 'filter=alertname="Watchdog"' --data-urlencode 'active=true' \
              | jq 'length')
            [ "$active" -gt 0 ] && exit 0
            now=$(date -u +%FT%TZ)
            ends=$(date -u -d '+10 min' +%FT%TZ)
            jq -n --arg now "$now" --arg ends "$ends" '[{
              labels: { alertname: "ClusterWatchdogMissing", severity: "critical" },
              annotations: { summary: "The cluster Watchdog stopped arriving: in-cluster alerting is down or unreachable." },
              startsAt: $now, endsAt: $ends
            }]' | curl -fsS --max-time 10 -H 'Content-Type: application/json' --data-binary @- ${api}
          '';
        };
        systemd.timers.alertmanager-watchdog-check = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            # Let a freshly started cluster or Alertmanager deliver first.
            OnBootSec = "10m";
            OnUnitActiveSec = "2m";
          };
        };

        networking.firewall.extraInputRules = lib.mkIf (nodes != [ ]) ''
          ip saddr { ${lib.concatStringsSep ", " nodes} } ip daddr ${address} tcp dport ${toString port} accept
        '';
      };
  };
}
