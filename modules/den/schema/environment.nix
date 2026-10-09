{
  lib,
  inputs,
  self,
  den,
  ...
}:
let
  inherit (lib) mkOption types;
  schemaLib = (inputs.gen.lib.mkGenLibs { }).schema;

  domainFor =
    {
      services,
      domain,
      ...
    }:
    serviceName:
    let
      svc = services.${serviceName} or { };
      # svc may be {} for an unknown service, so this must default rather
      # than `inherit (svc) delegateTo` (inherit has no fallback and would
      # crash with "attribute missing"). Bound as `delegate` (≠ the attr
      # name) so statix's W04 manual-inherit autofix can't rewrite it and
      # silently drop the `or null`.
      delegate = svc.delegateTo or null;
    in
    if svc ? domain && svc.domain != null then
      svc.domain
    else if delegate != null then
      "${serviceName}.${delegate}.${domain}"
    else
      "${serviceName}.${domain}";

  publicOf =
    dns: proxied:
    if dns.publicIPv4 == null then
      null
    else
      {
        address = dns.publicIPv4;
        inherit proxied;
      };

  addressOn =
    { name, networks, ... }:
    net: host:
    let
      ipToInt = ip: lib.foldl' (acc: o: acc * 256 + lib.toInt o) 0 (lib.splitString "." ip);
      cidr = lib.splitString "/" networks.${net}.cidr;
      blockSize = lib.foldl' (acc: _: acc * 2) 1 (lib.range 1 (32 - lib.toInt (lib.last cidr)));
      inNet = ip: ipToInt ip / blockSize == ipToInt (lib.head cidr) / blockSize;
      addrs = lib.concatMap (i: map (a: lib.head (lib.splitString "/" a)) i.ipv4) (
        lib.attrValues host.networking.interfaces
      );
    in
    lib.findFirst inNet
      (throw "den: host '${host.name}' has no IPv4 in ${name}.networks.${net} (${networks.${net}.cidr})")
      addrs;

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

      gatewayAsn = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "BGP AS number of the gateway router; its BGP peers and its own config read this one value";
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
  options.den.environments = schemaLib.mkInstanceRegistry {
    description = "Environment definitions for fleet topology and service resolution";
  } den.schema.environment;

  config = {
    den.schema.environment.isEntity = true;

    # Method: resolve the domain for a service, following delegation
    den.schema.environment.methods.getDomainFor = schemaLib.schemaFn {
      description = "Get the domain for a service, following delegation";
      type = lib.types.functionTo lib.types.str;
      fn = domainFor;
    };

    # Method: the host's IPv4 (prefix stripped) inside networks.<net>.cidr.
    den.schema.environment.methods.addressOn = schemaLib.schemaFn {
      description = "Get a host's IPv4 address on one of this environment's networks";
      type = lib.types.functionTo (lib.types.functionTo lib.types.str);
      fn = addressOn;
    };

    # Method: a served-domains quirk record for a host serving these services
    # (its nginx vhosts), addressed on the environment's default network.
    # `spec` is the service names, or { services; proxied ? true; } for names
    # the Cloudflare proxy must not front.
    den.schema.environment.methods.servedDomains = schemaLib.schemaFn {
      description = "Build a served-domains record for services a host serves";
      type = lib.types.functionTo (lib.types.functionTo lib.types.attrs);
      fn =
        # Named args: a method receives only the config keys its pattern names.
        env@{
          name,
          services,
          domain,
          networks,
          dns,
          ...
        }:
        host: spec:
        let
          s = if builtins.isList spec then { services = spec; } else spec;
        in
        {
          environment = env.name;
          host = host.name;
          address = addressOn env "default" host;
          domains = map (domainFor env) s.services;
          public = publicOf dns (s.proxied or true);
        };
    };

    # Method: the public half of a served-domains record: the edge address and
    # proxy mode, or null when the environment publishes no DNS.
    den.schema.environment.methods.publicOf = schemaLib.schemaFn {
      description = "The public DNS facts ({ address; proxied; } or null) for a name this environment serves";
      type = lib.types.functionTo (lib.types.nullOr lib.types.attrs);
      fn = { dns, ... }: publicOf dns;
    };

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

            dns = mkOption {
              type = types.submodule {
                options = {
                  publicIPv4 = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = ''
                      Public IPv4 address the environment's DNS A records point at (its served
                      names, and the domains' edge records when this is the edge environment).
                      null = this environment publishes no DNS records.
                    '';
                  };
                };
              };
              default = { };
              description = "The environment's public edge, for DNS records (modules/flake-parts/terranix)";
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
                options.ingest = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  example = "axon";
                  description = ''
                    Cluster whose telemetry ingest endpoint (the monitoring-ingest
                    quirk) this environment's hosts push metrics and logs to.
                    null: hosts ship nothing.
                  '';
                };
              };
              default = { };
              description = "Where this environment's hosts send telemetry";
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
  };
}
