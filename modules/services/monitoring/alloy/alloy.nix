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
        ];
      };

      networking.firewall.allowedTCPPorts = [ 12345 ];

      # User and group
      users.users.alloy = {
        isSystemUser = true;
        group = "alloy";
        home = "/var/lib/alloy";
        createHome = true;
        description = "Grafana Alloy user";
        extraGroups = [
          "systemd-journal" # allow to read the systemd journal for loki log forwarding
          "docker"
          "podman" # allow to read the docker socket
        ];
      };

      users.groups.alloy = { };

      systemd.services.alloy = {
        serviceConfig = {
          User = "alloy";
          Group = "alloy";
          DynamicUser = lib.mkForce false;
          SupplementaryGroups = [
            "systemd-journal"
            "docker"
            # "podman"
          ];
          # Add capabilities for process monitoring and network probing
          AmbientCapabilities = [
            "CAP_SYS_PTRACE"
            "CAP_DAC_READ_SEARCH"
            "CAP_NET_RAW"
          ];
          CapabilityBoundingSet = [
            "CAP_SYS_PTRACE"
            "CAP_DAC_READ_SEARCH"
            "CAP_NET_RAW"
          ];
        };
      };

      impermanence.ignorePaths = [
        "/var/lib/private/alloy/data-alloy/alloy_seed.json"
      ];

      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/alloy";
          user = "alloy";
          group = "alloy";
          mode = "0755";
        }
        {
          directory = "/etc/alloy";
          user = "alloy";
          group = "alloy";
          mode = "0755";
        }
      ];

      systemd.tmpfiles.rules = [
        "d /etc/alloy 0755 alloy alloy -"
        "d /var/lib/alloy 0755 alloy alloy -"
        "d /var/lib/alloy/data 0755 alloy alloy -"
      ];
    };
}
