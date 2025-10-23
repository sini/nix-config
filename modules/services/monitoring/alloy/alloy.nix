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
      reportingHosts = lib.mapAttrsToList (hostname: hostConfig: builtins.head hostConfig.ipv4) (
        lib.attrsets.filterAttrs (
          hostname: hostConfig:
          builtins.elem "metrics-ingester" hostConfig.roles && hostConfig.environment == targetEnvironment
        ) config.flake.hosts
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
            hostOptions.hostname
            reportingHost
            environment.name
            environment.gatewayIp
          ]
          (builtins.readFile ./configs/config.alloy.tmpl)
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

      networking.firewall.allowedTCPPorts = [ 12345 ];

      systemd.services.alloy = {
        serviceConfig = {
          User = "root";
          Group = "root";
          DynamicUser = lib.mkForce false;
        };
      };

      impermanence.ignorePaths = [
        "/var/lib/private/alloy/data-alloy/alloy_seed.json"
      ];

      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/alloy";
          user = "root";
          group = "root";
          mode = "0755";
        }
        {
          directory = "/etc/alloy";
          user = "root";
          group = "root";
          mode = "0755";
        }
      ];

      systemd.tmpfiles.rules = [
        "d /etc/alloy 0755 root root -"
        "d /var/lib/alloy 0755 root root -"
        "d /var/lib/alloy/data 0755 root root -"
      ];
    };
}
