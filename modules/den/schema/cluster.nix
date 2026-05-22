{ lib, ... }:
let
  inherit (lib) mkOption types;

  networkType = types.submodule {
    options = {
      cidr = mkOption {
        type = types.str;
        description = "Network CIDR (e.g., 172.20.0.0/16)";
      };

      ipv6_cidr = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "IPv6 network CIDR";
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "Human-readable description of the network";
      };

      gatewayIp = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Gateway IP address for this network";
      };

      gatewayIpV6 = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Gateway IPv6 address for this network";
      };

      dnsServers = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "DNS server IPs for this network";
      };

      assignments = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Static IP address assignments within this network";
      };
    };
  };
in
{
  den.schema.cluster.isEntity = true;
  den.schema.cluster.imports = [
    (_: {
      options = {
        # TODO: replace with schema.ref to den.environments once gen-schema
        # registry wiring is complete.
        environment = mkOption {
          type = types.str;
          description = "Name of the environment this cluster belongs to";
        };

        role = mkOption {
          type = types.nullOr types.str;
          default = "k3s";
          description = "Host role for auto-discovery. Hosts in the cluster's environment with this role are included.";
        };

        hosts = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          description = "Explicit list of host names in this cluster. When null, hosts are discovered via role.";
        };

        secretPath = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to the directory containing secrets for this cluster";
        };

        networks = mkOption {
          type = types.attrsOf networkType;
          default = { };
          description = "Cluster network definitions (pods, services, loadbalancers)";
        };
      };
    })
  ];
}
