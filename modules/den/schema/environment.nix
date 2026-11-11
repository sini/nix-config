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

  # The addresses among `addrs` (as declared, prefix length kept) inside
  # networks.<net>.ipv6_cidr; [ ] when the network has none.
  ipv6On =
    { networks, ... }:
    net: addrs:
    let
      cidr = networks.${net}.ipv6_cidr or null;
      parse = a: lib.network.ipv6.fromString a;
      c = parse cidr;
      groups =
        if lib.mod c.prefixLength 16 == 0 then
          c.prefixLength / 16
        else
          throw "den: networks.${net}.ipv6_cidr ${cidr}: a prefix length not a multiple of 16";
      head16 = a: lib.take groups (lib.splitString ":" (parse a).address);
    in
    if cidr == null then [ ] else lib.filter (a: head16 a == head16 cidr) addrs;

  ipToInt = ip: lib.foldl' (acc: o: acc * 256 + lib.toInt o) 0 (lib.splitString "." ip);
  intToIp =
    n:
    lib.concatMapStringsSep "." (s: toString (lib.mod (n / s) 256)) [
      16777216
      65536
      256
      1
    ];
  # { first; last; } addresses of an IPv4 CIDR, as integers.
  span =
    cidr:
    let
      parts = lib.splitString "/" cidr;
      size = lib.foldl' (acc: _: acc * 2) 1 (lib.range 1 (32 - lib.toInt (lib.last parts)));
      first = ipToInt (lib.head parts) / size * size;
    in
    {
      inherit first;
      last = first + size - 1;
    };

  networkType = types.submodule (
    { config, ... }:
    {
      options = {
        cidr = mkOption {
          type = types.str;
          description = "Network CIDR (e.g., 10.0.0.0/24)";
        };

        staticCidr = mkOption {
          type = types.nullOr types.str;
          default =
            if lib.toInt (lib.last (lib.splitString "/" config.cidr)) < 24 then
              "${intToIp (span config.cidr).first}/24"
            else
              null;
          defaultText = lib.literalMD "the first /24 of `cidr` when `cidr` is wider, else null";
          description = ''
            The block reserved for static services (gateway, L2 LoadBalancer pools), kept
            out of DHCP. Hosts outside it (10.10.10.x on prod) are older statics.
          '';
        };

        dhcpRange = mkOption {
          type = types.nullOr (
            types.submodule {
              options.start = mkOption { type = types.str; };
              options.stop = mkOption { type = types.str; };
            }
          );
          readOnly = true;
          default =
            if config.staticCidr == null then
              null
            else
              {
                # The block's next address is the network's x.y.1.0 on a /16; start one past it.
                start = intToIp ((span config.staticCidr).last + 2);
                stop = intToIp ((span config.cidr).last - 1);
              };
          defaultText = lib.literalMD "the rest of `cidr` after `staticCidr`, without the broadcast address";
          description = ''
            The DHCP pool, derived from cidr and staticCidr. The unifi workspace writes it
            as the controller network's dhcpd_start/dhcpd_stop (docs/dns-resolver.md §2.4(a)).
          '';
        };

        ipv6_cidr = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            IPv6 network CIDR (e.g., a ULA fdxx:xxxx:xxxx::/64). A host's interface
            address inside it is advertised on-link to the LAN (core/network/networking.nix).
          '';
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

        unifiNetwork = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            The UniFi controller's name (networkconf `name`) for this network. The
            unifi workspace writes its DHCP and IPv6 DNS from dns.resolvers
            (docs/dns-resolver.md §2.4(a)). null = the controller's DNS settings stay unmanaged.
          '';
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
    }
  );

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

    # Method: the addresses of a list inside networks.<net>.ipv6_cidr.
    den.schema.environment.methods.ipv6On = schemaLib.schemaFn {
      description = "Filter IPv6 addresses to those inside one of this environment's networks' ipv6_cidr";
      type = lib.types.functionTo (lib.types.functionTo (lib.types.listOf lib.types.str));
      fn = ipv6On;
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
                  resolvers = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = ''
                      Ordered names of the filtering resolver instances (a host or a cluster
                      emitting a dns-resolvers record) this environment's clients use.
                      [ ] = clients keep their own resolver lists.
                    '';
                  };
                  dhcpResolvers = mkOption {
                    type = types.listOf types.str;
                    default = config.dns.resolvers;
                    defaultText = lib.literalExpression "dns.resolvers";
                    description = ''
                      The instances the controller network (networks.default.unifiNetwork)
                      hands its DHCP clients, which den does not route. Defaults to
                      dns.resolvers; an environment sets it when its DHCP clients cannot
                      reach an instance the hosts can.
                    '';
                  };
                  roamingResolvers = mkOption {
                    type = types.listOf types.str;
                    default = config.dns.resolvers;
                    defaultText = lib.literalExpression "dns.resolvers";
                    description = ''
                      The instances headscale hands roaming devices (its global nameservers,
                      ahead of the upstreams). Defaults to dns.resolvers; an environment sets
                      it when an instance is not proven reachable over the tailnet.
                    '';
                  };
                  filter = mkOption {
                    type = types.submodule {
                      options = {
                        denylists = mkOption {
                          type = types.listOf types.str;
                          default = [ ];
                          description = "Denylist URLs, downloaded by every resolver instance at runtime";
                        };
                        allowlist = mkOption {
                          type = types.listOf types.str;
                          default = [ ];
                          description = "Inline domains every resolver instance never blocks";
                        };
                      };
                    };
                    default = { };
                    description = "The filter every resolver instance in this environment applies";
                  };
                  internal = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = ''
                      The cluster whose dns-internal record (its CoreDNS) a resolver instance
                      sends this environment's served names to. A resolver host's environment
                      must set it.
                    '';
                  };
                };
              };
              default = { };
              description = "The environment's DNS: its public edge records, and the resolver instances, filter and internal upstream its clients use (docs/dns-resolver.md)";
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

            sshFrom = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "prod" ];
              description = ''
                Other environments whose default network may reach this environment's hosts'
                sshd over the LAN, beside its own: the host-side mirror of a gateway policy
                letting that network in (prod's unifi.networkPolicies).
              '';
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
