{
  lib,
  self,
  ...
}:
let
  inherit (lib) types mkOption;
  inherit (self.lib.modules) mkUsersWithFeaturesOpt;
in
{
  config.text.readme.parts.environment-options =
    # markdown
    ''
      ## Environment Options

      This repository defines environment settings in the `flake.environments` attribute set.
      Each environment contains network and infrastructure configuration that can be shared
      across hosts. These options define the infrastructure topology and include:

      - `name`: Human-readable environment name (e.g., "dev", "prod").
      - `domain`: Base domain for the environment (e.g., "json64.dev").
      - `gatewayIp`: Gateway IP address for the environment's primary network.
      - `dnsServers`: List of DNS server IPs for the environment.
      - `networks`: Network definitions including IPv4/IPv6 subnets and purposes.
      - `ipv6`: IPv6 ULA prefix configuration for NPTv6 translation.
      - `kubernetes`: Kubernetes-specific network configuration.
      - `email`: Default email settings for the environment.
      - `acme`: ACME certificate authority settings.

    '';

  options.flake.environments =
    let
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

          purpose = mkOption {
            type = types.str;
            description = "Network purpose (e.g., management, cluster, service)";
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable description of the network";
          };
        };
      };

      kubernetesType = types.submodule {
        options = {
          clusterCidr = mkOption {
            type = types.str;
            default = "172.20.0.0/16";
            description = "Kubernetes pod network CIDR";
          };

          serviceCidr = mkOption {
            type = types.str;
            default = "172.21.0.0/16";
            description = "Kubernetes service network CIDR";
          };

          internalMeshCidr = mkOption {
            type = types.str;
            default = "172.16.255.0/24";
            description = "Internal mesh network for Kubernetes nodes";
          };

          tlsSanIps = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional IPs to include in Kubernetes API server TLS certificate SANs";
          };

          loadBalancerRange = mkOption {
            type = types.str;
            default = "10.0.100.0/24";
            description = "IP range for LoadBalancer services";
          };
        };
      };

      emailType = types.submodule {
        options = {
          domain = mkOption {
            type = types.str;
            description = "Email domain (e.g., json64.dev)";
          };

          adminEmail = mkOption {
            type = types.str;
            description = "Default admin email address";
          };
        };
      };

      acmeType = types.submodule {
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

      environmentType = types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Human-readable environment name";
          };

          domain = mkOption {
            type = types.str;
            description = "Base domain for the environment";
          };

          gatewayIp = mkOption {
            type = types.str;
            description = "Gateway IP address for the environment";
          };

          gatewayIpV6 = mkOption {
            type = types.str;
            description = "Gateway IPv6 address for the environment";
          };

          dnsServers = mkOption {
            type = types.listOf types.str;
            default = [
              "1.1.1.1"
              "8.8.8.8"
            ];
            description = "DNS server IPs for the environment";
          };

          networks = mkOption {
            type = types.attrsOf networkType;
            default = { };
            description = ''
              Network definitions for the environment.
              Example: `{
                management = { cidr = "10.0.0.0/24"; purpose = "management"; };
                cluster = { cidr = "172.20.0.0/16"; purpose = "kubernetes-pods"; };
              }`
            '';
          };

          kubernetes = mkOption {
            type = kubernetesType;
            default = { };
            description = "Kubernetes-specific network configuration";
          };

          email = mkOption {
            type = emailType;
            description = "Email configuration for the environment";
          };

          acme = mkOption {
            type = acmeType;
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

          delegation = mkOption {
            type = types.submodule {
              options = {
                metricsTo = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Environment to delegate metrics reporting to (e.g., 'prod')";
                };

                authTo = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Environment to delegate authentication to (e.g., 'prod')";
                };

                logsTo = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Environment to delegate log shipping to (e.g., 'prod')";
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
                  description = "Additional environments to scan for metrics (e.g., ['dev'] for prod scanning dev)";
                };
              };
            };
            default = { };
            description = "Monitoring configuration including cross-environment scanning";
          };

          users = mkUsersWithFeaturesOpt "Users in this environment with their features and configuration";

          ipv6 = mkOption {
            type = types.submodule {
              options = {
                ula_prefix = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "ULA prefix for the environment (e.g., fd64::/48)";
                };

                management_prefix = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "IPv6 prefix for management network (e.g., fd64:0:1::/64)";
                };

                kubernetes_prefix = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "IPv6 prefix for Kubernetes pods (e.g., fd64:0:2::/64)";
                };

                services_prefix = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "IPv6 prefix for Kubernetes services (e.g., fd64:0:3::/64)";
                };

                external_prefix = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "External ISP prefix for NPTv6 translation (e.g., 2001:db8::/64)";
                };
              };
            };
            default = { };
            description = "IPv6 ULA and prefix configuration for NPTv6 translation";
          };
        };
      };
    in
    mkOption {
      type = types.attrsOf environmentType;
      default = { };
      description = "Environment configurations";
    };
}
