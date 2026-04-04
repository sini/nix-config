# Grafana Alloy metrics agent.
#
# NOTE: Settings that should be typed (not yet in schema):
#   - (none — uses environment.delegation.logsTo and host discovery)
{ den, lib, ... }:
{
  den.aspects.alloy = {
    includes = lib.attrValues den.aspects.alloy._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          nixos =
            {
              config,
              pkgs,
              lib,
              ...
            }:
            let
              currentHostEnvironment = host.environment;

              # Determine target environment for log shipping (check for delegation)
              targetEnvironment =
                if environment.delegation.logsTo != null then
                  environment.delegation.logsTo
                else
                  currentHostEnvironment;

              # Find the first host with the metrics-ingester feature in target environment
              reportingHosts = lib.mapAttrsToList (_hostname: hostConfig: builtins.head hostConfig.ipv4) (
                lib.attrsets.filterAttrs (
                  _hostname: hostConfig:
                  hostConfig.hasFeature "metrics-ingester" && hostConfig.environment == targetEnvironment
                ) config.den.hosts
              );

              reportingHost = if reportingHosts != [ ] then lib.head reportingHosts else null;

              # Generate the Alloy configuration from template
              alloyConfig = pkgs.writeText "config.alloy" (
                builtins.replaceStrings
                  [
                    "\${hostname}"
                    "\${reportingHost}"
                    "\${environment}"
                    "\${gatewayIP}"
                  ]
                  [
                    host.hostname
                    reportingHost
                    environment.name
                    environment.networks.default.gatewayIp
                  ]
                  (builtins.readFile ./alloy-configs/config.alloy.tmpl)
              );
            in
            {
              # Create configuration files
              environment.etc = {
                "alloy/config.alloy" = {
                  source = alloyConfig;
                  mode = "0640";
                  user = "alloy";
                  group = "alloy";
                };
                "alloy/blackbox.yml" = {
                  source = ./alloy-configs/blackbox.yml;
                  mode = "0640";
                  user = "alloy";
                  group = "alloy";
                };
                "alloy/snmp.yml" = {
                  source = ./alloy-configs/snmp.yml;
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
        }
      );

      firewall = den.lib.perHost {
        firewall.allowedTCPPorts = [ 12345 ];
      };

      impermanence = den.lib.perHost {
        persist.directories = [
          {
            directory = "/var/lib/alloy";
            user = "root";
            group = "root";
            mode = "0755";
          }
        ];
      };
    };
  };
}
