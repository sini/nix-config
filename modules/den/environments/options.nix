# Den-native environment type and option.
# Environments are defined in den.environments.<name> and resolved onto hosts
# via enrichHost in resolve-environment.nix.
{ lib, den, ... }:
let
  networkType = lib.types.submodule {
    options = {
      cidr = lib.mkOption {
        type = lib.types.str;
        description = "IPv4 CIDR";
      };
      ipv6_cidr = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "IPv6 CIDR";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      gatewayIp = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      gatewayIpV6 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      dnsServers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      assignments = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Named IP assignments within this network";
      };
      wireless = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              ssid = lib.mkOption { type = lib.types.str; };
              pskRef = lib.mkOption { type = lib.types.str; };
            };
          }
        );
        default = null;
      };
    };
  };

  certificateIssuerType = lib.types.submodule {
    options = {
      ageKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };
  };

  certificateDomainType = lib.types.submodule {
    options = {
      issuer = lib.mkOption { type = lib.types.str; };
    };
  };

  serviceDomainType = lib.types.submodule {
    options = {
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      delegateTo = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Delegate this service to another environment";
      };
    };
  };

  environmentType = lib.types.submodule (
    { name, config, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          readOnly = true;
        };
        id = lib.mkOption { type = lib.types.int; };
        domain = lib.mkOption { type = lib.types.str; };
        secretPath = lib.mkOption {
          type = lib.types.either lib.types.str lib.types.path;
          default = ".secrets/environments/${name}";
        };
        timezone = lib.mkOption {
          type = lib.types.str;
          default = "UTC";
        };
        location = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
        };
        tags = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
        };

        networks = lib.mkOption {
          type = lib.types.attrsOf networkType;
          default = { };
        };

        email = lib.mkOption {
          type = lib.types.submodule {
            options = {
              domain = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              adminEmail = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
            };
          };
          default = { };
        };

        acme = lib.mkOption {
          type = lib.types.submodule {
            options = {
              server = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              dnsProvider = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              dnsResolver = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
            };
          };
          default = { };
        };

        certificates = lib.mkOption {
          type = lib.types.submodule {
            options = {
              issuers = lib.mkOption {
                type = lib.types.attrsOf certificateIssuerType;
                default = { };
              };
              domains = lib.mkOption {
                type = lib.types.attrsOf certificateDomainType;
                default = { };
              };
            };
          };
          default = { };
        };

        services = lib.mkOption {
          type = lib.types.attrsOf serviceDomainType;
          default = { };
        };

        wirelessSecretsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
        };

        delegation = lib.mkOption {
          type = lib.types.submodule {
            options = {
              metricsTo = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              authTo = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              logsTo = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
            };
          };
          default = { };
        };

        monitoring = lib.mkOption {
          type = lib.types.submodule {
            options = {
              scanEnvironments = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
            };
          };
          default = { };
        };

        system-access-groups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };

        access = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          default = { };
          description = "ACL: username → [group names]";
        };

        users = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Per-user overrides (nullable fields)";
        };

        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Default feature settings for all hosts in this environment";
        };

        # Computed helpers
        getDomainFor = lib.mkOption {
          type = lib.types.functionTo lib.types.str;
          readOnly = true;
          default =
            serviceName:
            let
              svc = config.services.${serviceName} or { };
              delegatedTo = svc.delegateTo or null;
            in
            if svc.domain or null != null then
              svc.domain
            else if delegatedTo != null then
              "${serviceName}.${delegatedTo}.${config.domain}"
            else
              "${serviceName}.${name}.${config.domain}";
        };

        getTopDomainFor = lib.mkOption {
          type = lib.types.functionTo lib.types.str;
          readOnly = true;
          default =
            serviceName:
            let
              full = config.getDomainFor serviceName;
              parts = lib.splitString "." full;
              len = builtins.length parts;
            in
            lib.concatStringsSep "." (lib.sublist (len - 2) 2 parts);
        };

        getAssignment = lib.mkOption {
          type = lib.types.functionTo lib.types.str;
          readOnly = true;
          default =
            assignmentName:
            let
              found = lib.findFirst (_: net: net.assignments ? ${assignmentName}) null (
                lib.mapAttrsToList (name: net: { inherit name net; }) config.networks
              );
            in
            if found != null then
              found.net.assignments.${assignmentName}
            else
              throw "Assignment '${assignmentName}' not found in environment '${name}'";
        };

        # Den-native findHostsByFeature — reads from den.hosts, not config.hosts
        findHostsByFeature = lib.mkOption {
          type = lib.types.functionTo (lib.types.attrsOf lib.types.anything);
          readOnly = true;
          default =
            _featureName:
            let
              allDenHosts = lib.concatMapAttrs (_sys: hosts: hosts) (den.hosts or { });
            in
            lib.filterAttrs (_hostName: host: (host.environment or "") == name) allDenHosts;
          description = "Find den hosts in this environment that include a given aspect";
        };
      };
    }
  );
in
{
  options.den.environments = lib.mkOption {
    type = lib.types.attrsOf environmentType;
    default = { };
    description = "Den-native environment definitions";
  };
}
