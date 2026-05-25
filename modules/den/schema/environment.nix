{
  lib,
  inputs,
  self,
  ...
}:
let
  inherit (lib) mkOption types;
  schemaLib = inputs.gen-schema.lib;

  networkType = types.submodule {
    options = {
      cidr = mkOption {
        type = types.str;
        description = "Network CIDR (e.g., 10.0.0.0/24)";
      };

      ipv6_cidr = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "IPv6 network CIDR (e.g., fd64:0:1::/64)";
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
        description = "Static IP address assignments within this network.";
      };

      wireless = mkOption {
        type = types.nullOr (
          types.submodule {
            options = {
              ssid = mkOption {
                type = types.str;
                description = "SSID of the wireless network";
              };
              pskRef = mkOption {
                type = types.str;
                description = "PSK reference for the wireless network (e.g., ext:psk_arcade)";
              };
            };
          }
        );
        default = null;
        description = "Wireless network configuration";
      };
    };
  };

  serviceType = types.submodule {
    options = {
      domain = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override domain for this service.";
      };

      delegateTo = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Name of another environment to delegate this service to.";
      };
    };
  };

  certificatesType = types.submodule {
    options = {
      domains = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              issuer = mkOption {
                type = types.str;
                description = "The issuer name to use for this domain";
              };
            };
          }
        );
        default = { };
        description = "Domains to generate certificates for";
      };

      issuers = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              ageKeyFile = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Path to the file containing the API key (agenix)";
              };
            };
          }
        );
        default = { };
        description = "Certificate issuer configurations";
      };
    };
  };
in
{
  den.schema.environment.isEntity = true;

  # Method: resolve the domain for a service, following delegation
  den.schema.environment.methods.getDomainFor =
    schemaLib.schemaFn "Get the domain for a service, following delegation"
      (lib.types.functionTo lib.types.str)
      (
        {
          services,
          domain,
          ...
        }:
        serviceName:
        let
          svc = services.${serviceName} or { };
          inherit (svc) delegateTo;
        in
        if svc ? domain && svc.domain != null then
          svc.domain
        else if delegateTo != null then
          "${serviceName}.${delegateTo}.${domain}"
        else
          "${serviceName}.${domain}"
      );

  den.schema.environment.imports = [
    (
      { config, ... }:
      {
        options = {
          id = mkOption {
            type = types.int;
            default = 0;
            description = "Numeric ID of the environment";
          };

          domain = mkOption {
            type = types.str;
            description = "Base domain for the environment";
          };

          secretPath = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to the directory containing secrets for this environment";
          };

          wirelessSecretsFile = mkOption {
            type = types.path;
            default = config.secretPath + "/wpa_supplicant_psks.age";
            description = "Path to WPA supplicant secrets file (agenix encrypted)";
          };

          settings =
            mkOption {
              type = types.attrsOf (types.attrsOf types.anything);
              default = { };
              description = "Environment-level default feature settings for scope-engine cascade";
            }
            // {
              identity = false;
            };

          networks = mkOption {
            type = types.attrsOf networkType;
            default = { };
            description = "Network definitions for the environment";
          };

          services = mkOption {
            type = types.attrsOf serviceType;
            default = { };
            description = "Service-specific domain mappings for the environment";
          };

          certificates = mkOption {
            type = certificatesType;
            default = { };
            description = "Certificate management configuration";
          };

          email = mkOption {
            type = types.submodule {
              options = {
                domain = mkOption {
                  type = types.str;
                  default = "";
                  description = "Email domain";
                };
                adminEmail = mkOption {
                  type = types.str;
                  default = "";
                  description = "Default admin email address";
                };
              };
            };
            default = { };
            description = "Email configuration for the environment";
          };

          acme = mkOption {
            type = types.submodule {
              options = {
                server = mkOption {
                  type = types.str;
                  default = "https://acme-v02.api.letsencrypt.org/directory";
                  description = "ACME server URL";
                };
                dnsProvider = mkOption {
                  type = types.str;
                  default = "cloudflare";
                  description = "DNS provider for ACME challenges";
                };
                dnsResolver = mkOption {
                  type = types.str;
                  default = "1.1.1.1:53";
                  description = "DNS resolver for ACME validation";
                };
              };
            };
            default = { };
            description = "ACME certificate authority configuration";
          };

          timezone = mkOption {
            type = types.str;
            default = "UTC";
            description = "Default timezone for the environment";
          };

          location = mkOption {
            type = types.submodule {
              options = {
                country = mkOption {
                  type = types.str;
                  default = "US";
                  description = "ISO country code";
                };
                region = mkOption {
                  type = types.str;
                  default = "";
                  description = "Geographic region or datacenter";
                };
              };
            };
            default = { };
            description = "Geographic location information";
          };

          tags = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = "Environment-wide tags for metadata and organization";
          };

          # TODO: delegation targets should become schema.ref to den.environments
          # once gen-schema registry wiring is complete.
          delegation = mkOption {
            type = types.submodule {
              options = {
                metricsTo = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Environment to delegate metrics reporting to";
                };
                authTo = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Environment to delegate authentication to";
                };
                logsTo = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Environment to delegate log shipping to";
                };
              };
            };
            default = { };
            description = "Cross-environment delegation configuration";
          };

          monitoring = mkOption {
            type = types.submodule {
              options = {
                scanEnvironments = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "Additional environments to scan for metrics";
                };
              };
            };
            default = { };
            description = "Monitoring configuration including cross-environment scanning";
          };

          system-access-groups = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "System-scoped groups that grant Unix account creation on all hosts in this environment";
          };

          access = mkOption {
            type = types.attrsOf (types.listOf types.str);
            default = { };
            description = "Maps usernames to lists of group names for this environment";
          };
        };

        config = {
          secretPath = lib.mkDefault (self + "/.secrets/env/${config.name}");
        };
      }
    )
  ];
}
