{
  lib,
  self,
  config,
  rootPath,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (self.lib.modules) mkUsersWithFeaturesOpt;
  inherit (self.lib.kubernetes-services) kubernetesConfigType;
  flakeConfig = config; # Capture the flake-level config for use in submodules
in
{
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
            description = ''
              Static IP address assignments within this network.
              Maps service/resource names to their assigned IP addresses.
              Example: { kube-apiserver-vip = "10.9.0.100"; }
            '';
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

      environmentType = types.submodule (
        {
          name,
          config,
          ...
        }:
        {
          options = {
            name = mkOption {
              type = types.str;
              default = name;
              readOnly = true;
              description = "Human-readable environment name";
            };

            id = mkOption {
              type = types.int;
              default = 1;
              description = "ID of the environment";
            };

            domain = mkOption {
              type = types.str;
              description = "Base domain for the environment";
            };

            certificates = mkOption {
              type = types.submodule {
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
                    description = "Domains to generate certificates for (typically wildcard certs)";
                  };

                  issuers = mkOption {
                    type = types.attrsOf (
                      types.submodule {
                        options = {
                          ageKeyFile = mkOption {
                            type = types.nullOr types.path;
                            default = null;
                            description = "Optional path to the file containing the API key (agenix)";
                          };
                          sopsFile = mkOption {
                            type = types.nullOr types.path;
                            default = null;
                            description = "Optional path to the SOPS file containing the API key";
                          };
                          secretKey = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                            description = "The secret key name within the secrets file";
                          };
                        };
                      }
                    );
                    default = { };
                    description = "Certificate issuer configurations (e.g., ACME DNS API credentials)";
                  };
                };
              };
              default = { };
              description = "Certificate management configuration for the environment";
            };

            services = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = {
                    domain = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = ''
                        Override domain for this service.
                        If null, defaults to <service-name>.''${environment.domain}
                      '';
                    };

                    delegateTo = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = ''
                        Name of another environment to delegate this service to.
                        When set, the service is considered to be hosted by the specified environment.
                      '';
                    };
                  };
                }
              );
              default = { };
              description = ''
                Service-specific domain mappings for the environment.
                Used by OAuth2 provisioning, ingress configuration, and service discovery.
                Example: services.argocd.domain = "argocd.zeroday.run";
              '';
            };

            networks = mkOption {
              type = types.attrsOf networkType;
              default = { };
              description = ''
                Network definitions for the environment.
                Network names should match their purpose (e.g., default, kubernetes-pods, kubernetes-services).
                Example: `{
                  default = { cidr = "10.0.0.0/24"; };
                  kubernetes-pods = { cidr = "172.20.0.0/16"; };
                }`
              '';
            };

            kubernetes = mkOption {
              type = kubernetesConfigType;
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

            users = mkUsersWithFeaturesOpt ''
              Users in this environment with their identity, Unix account, and home configuration.
              Set enableUnixAccount = true for users that should be created on hosts.
            '';

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

            getDomainFor = mkOption {
              type = types.functionTo types.str;
              readOnly = true;
              description = ''
                Helper function to get the domain for a service.
                Returns the configured service domain or defaults to <service-name>.<environment.domain>
              '';
            };

            domainToResourceName = mkOption {
              type = types.functionTo types.str;
              readOnly = true;
              description = ''
                Helper function to convert a domain to a Kubernetes resource name.
                Takes the last 2 parts of the domain (e.g., "json64-dev" from "argocd.prod.json64.dev").
              '';
            };

            getTopDomainFor = mkOption {
              type = types.functionTo types.str;
              readOnly = true;
              description = ''
                Helper function to get the top-level domain for a service.
                Returns the last 2 parts of the service domain as a string (e.g., "json64.dev" from "argocd.prod.json64.dev").
              '';
            };

            getAssignment = mkOption {
              type = types.functionTo (types.nullOr types.str);
              readOnly = true;
              description = ''
                Helper function to get an IP assignment by name across all networks.
                Returns the IP address if found, null otherwise.
                Example: getAssignment "kube-apiserver-vip" → "10.9.0.100"
              '';
            };

            findHostsByRole = mkOption {
              type = types.functionTo (types.attrsOf types.unspecified);
              readOnly = true;
              description = ''
                Helper function to find all hosts in this environment that have a specific role.
                Returns an attrset of hosts filtered by the specified role.
              '';
            };

            secrets = mkOption {
              type = types.unspecified;
              readOnly = true;
              description = ''
                Secret helper functions for this environment.
                Provides: from, for, forInlineFor, forOidcService, oidcIssuerFor
              '';
            };
          };

          config = {
            getDomainFor =
              serviceName:
              if config.services ? ${serviceName} && config.services.${serviceName}.domain != null then
                config.services.${serviceName}.domain
              else
                "${serviceName}.${config.domain}";

            domainToResourceName =
              domain:
              let
                parts = lib.splitString "." domain;
                # Take the last 2 parts (e.g., ["json64", "dev"] from "argocd.prod.json64.dev")
                topDomain = lib.reverseList (lib.take 2 (lib.reverseList parts));
              in
              lib.concatStringsSep "-" topDomain;

            getTopDomainFor =
              service:
              let
                domain = config.getDomainFor service;
                parts = lib.splitString "." domain;
                # Take the last 2 parts (e.g., ["json64", "dev"] from "argocd.prod.json64.dev")
                topDomain = lib.reverseList (lib.take 2 (lib.reverseList parts));
              in
              lib.concatStringsSep "." topDomain;

            getAssignment =
              let
                # Capture networks in closure to avoid evaluation issues
                inherit (config) networks;
              in
              name:
              let
                # Flatten all assignments from all networks into a single list
                allAssignments = lib.flatten (
                  lib.mapAttrsToList (
                    netName: net:
                    lib.mapAttrsToList (assignName: addr: {
                      inherit assignName addr;
                      network = netName;
                    }) (net.assignments or { })
                  ) networks
                );
                # Find the first matching assignment
                match = lib.findFirst (a: a.assignName == name) null allAssignments;
              in
              if match != null then match.addr else null;

            findHostsByRole =
              role:
              let
                hosts = flakeConfig.flake.hosts;
              in
              hosts
              |> lib.attrsets.filterAttrs (
                _hostname: hostConfig:
                (builtins.elem role (hostConfig.roles or [ ])) && (hostConfig.environment == config.name)
              );

            secrets =
              let
                credentialsEnv =
                  if config.kubernetes.sso.credentialsEnvironment != null then
                    config.kubernetes.sso.credentialsEnvironment
                  else
                    config.name;
              in
              {
                from =
                  {
                    sopsFile ? config.kubernetes.secretsFile,
                    secretKey,
                    ...
                  }:
                  "ref+sops://${sopsFile}#${secretKey}";

                for = secretName: "ref+sops://${config.kubernetes.secretsFile}#${secretName}";
                forInlineFor = secretName: "ref+sops://${config.kubernetes.secretsFile}#${secretName}+";
                forOidcService =
                  name:
                  "ref+sops://${rootPath}/.secrets/env/${credentialsEnv}/oidc/${name}-oidc-client-secret.enc.yaml#${name}-oidc-client-secret";
                oidcIssuerFor =
                  clientID:
                  let
                    pattern =
                      if config.kubernetes.sso.issuerPattern != null then
                        config.kubernetes.sso.issuerPattern
                      else
                        let
                          # Look up credentials environment
                          environments = config.flake.environments or { };
                          credEnv = environments.${credentialsEnv} or null;
                          domain = if credEnv != null then credEnv.domain else config.domain;
                        in
                        "https://idm.${domain}/oauth2/openid/{clientID}";
                  in
                  lib.replaceStrings [ "{clientID}" ] [ clientID ] pattern;
              };
          };
        }
      );
    in
    mkOption {
      type = types.attrsOf environmentType;
      default = { };
      description = "Environment configurations";
    };
}
