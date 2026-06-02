# Grafana Alloy — unified observability agent with log collection,
# metrics scraping, network probing, and SNMP monitoring.
#
# Ported from main:modules/services/monitoring/alloy/
{ lib, ... }:
{
  den.aspects.services.alloy = {
    nixos =
      {
        pkgs,
        environment,
        host,
        prometheus-targets,
        ...
      }:
      let
        # Resolve target environment following delegation (logsTo → metricsTo → self)
        inherit (environment) delegation;
        targetEnvironment =
          if delegation.logsTo or null != null then
            delegation.logsTo
          else if delegation.metricsTo or null != null then
            delegation.metricsTo
          else
            host.environment;

        # Find the metrics-ingester host via prometheus-targets pipe:
        # the host running prometheus in the target environment is the ingester.
        # (Delegation may target another environment, so filter explicitly.)
        targetIps = lib.unique (
          map (t: t.ip) (lib.filter (t: t.environment.name == targetEnvironment) prometheus-targets)
        );
        reportingHost = if targetIps != [ ] then lib.head targetIps else null;

        alloyConfig = pkgs.writeText "config.alloy" (
          builtins.replaceStrings
            [
              "\${hostname}"
              "\${reportingHost}"
              "\${environment}"
              "\${gatewayIP}"
            ]
            [
              host.name
              (if reportingHost != null then reportingHost else "localhost")
              environment.name
              (environment.networks.default.gatewayIp or "10.10.0.1")
            ]
            (builtins.readFile ./configs/config.alloy.tmpl)
        );
      in
      {
        environment.etc = {
          "alloy/config.alloy" = {
            source = alloyConfig;
            mode = "0640";
            user = "alloy";
            group = "alloy";
          };
          "alloy/blackbox.yml" = {
            source = ./configs/blackbox.yml;
            mode = "0640";
            user = "alloy";
            group = "alloy";
          };
          "alloy/snmp.yml" = {
            source = ./configs/snmp.yml;
            mode = "0640";
            user = "alloy";
            group = "alloy";
          };
        };

        services.alloy = lib.mkIf (reportingHost != null) {
          enable = true;
          configPath = "/etc/alloy/";
          extraFlags = [
            "--disable-reporting"
            "--storage.path=/var/lib/alloy/data"
          ];
        };

        systemd.services.alloy = {
          serviceConfig = {
            User = "root";
            Group = "root";
            DynamicUser = lib.mkForce false;
          };
        };

        impermanence.ignorePaths = [
          "/var/lib/private/alloy/data-alloy/alloy_seed.json"
          "/etc/alloy/"
        ];

        systemd.tmpfiles.rules = [
          "d /etc/alloy 0755 root root -"
          "d /var/lib/alloy 0755 root root -"
          "d /var/lib/alloy/data 0755 root root -"
        ];
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [ 12345 ];
    };

    persist = {
      directories = [
        {
          directory = "/var/lib/alloy";
          user = "root";
          group = "root";
          mode = "0755";
        }
      ];
    };
  };
}
