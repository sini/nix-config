{ den, lib, ... }:
let
  serviceDomains = [ "headscale" ];
  # DERP's STUN listener and tailscaled's WireGuard port.
  udpPorts = [
    3478
    41641
  ];
  portList = lib.concatMapStringsSep "," toString udpPorts;
in
{
  den.aspects.services.networking.headscale = {
    # headscale's settings and ACL policy, shared by this host aspect and the cluster's
    # pod (kubernetes/services/network/headscale.nix), so both render one control
    # plane. The caller supplies what differs by where it runs: the DERP region code,
    # the OIDC secret path and the policy file's path.
    settings.shared = lib.mkOption {
      type = lib.types.raw;
      description = "{ policy = exit-nodes -> policy; settings = args -> headscale settings; }";
      default =
        let
          resolvers = import ../../core/network/_resolvers.nix { inherit lib; };
        in
        {
          # The ACL policy: everything may reach everything, and each host's exit node is
          # auto-approved (it joins as its own user, tailscale/secrets.nix).
          policy = exit-nodes: {
            acls = [
              {
                action = "accept";
                src = [ "*" ];
                dst = [ "*:*" ];
              }
            ];
            autoApprovers.exitNode = map (n: "${n.hostname}@") exit-nodes;
          };

          settings =
            {
              environment,
              dns-resolvers,
              regionCode,
              oidcSecretPath,
              policyPath,
            }:
            {
              server_url = "https://${environment.getDomainFor "headscale"}";
              logtail = {
                enabled = false;
              };
              prefixes = {
                v4 = "100.72.0.0/16";
                v6 = "fd7a:115c:a1e0::/48";
                allocation = "random";
              };
              derp = {
                server = {
                  enabled = true;
                  region_id = 999;
                  region_code = regionCode;
                  region_name = regionCode + " DERP";
                  stun_listen_addr = "0.0.0.0:3478";
                  auto_update_enabled = true;
                  automatically_add_embedded_derp_region = true;
                };
              };

              dns = {
                magic_dns = true;
                base_domain = "ts.${environment.domain}";
                override_local_dns = true;
                # Roaming devices (docs/dns-resolver.md §2.4c): the filtering resolvers
                # without the gateway (private, so tailscaled would race it at once, and
                # unreachable off the LAN), then the environment's upstreams, which
                # tailscaled upgrades to DoH, so off-LAN clients and an outage keep DNS.
                nameservers.global =
                  lib.optionals (environment.dns.roamingResolvers != [ ]) (
                    resolvers.resolversFor {
                      gateway = false;
                      list = "roamingResolvers";
                    } environment dns-resolvers
                  )
                  ++ resolvers.plainUpstreams environment;
              };

              oidc = {
                only_start_if_oidc_is_available = true;
                issuer = "https://${environment.getDomainFor "kanidm"}/oauth2/openid/headscale";
                client_id = "headscale";
                client_secret_path = oidcSecretPath;
                scope = [
                  "openid"
                  "profile"
                  "email"
                ];
                pkce = {
                  enabled = true;
                  method = "S256";
                };
              };

              policy.path = policyPath;
            };
        };
    };

    includes = [ den.aspects.services.networking.nginx ];

    nixos =
      {
        config,
        dns-resolvers,
        exit-nodes,
        environment,
        host,
        pkgs,
        ...
      }:
      let
        domain = environment.getDomainFor "headscale";
        kanidmDomain = environment.getDomainFor "kanidm";
      in
      {
        services = {
          headscale = {
            enable = true;
            address = "0.0.0.0";
            port = 8085;

            settings = {
              metrics_listen_addr = "127.0.0.1:8090";
            }
            // host.settings.services.networking.headscale.shared.settings {
              inherit environment dns-resolvers;
              regionCode = config.networking.hostName;
              oidcSecretPath = config.age.secrets.headscale-oidc-secret.path;
              policyPath = pkgs.writeText "policy.json" (
                builtins.toJSON (host.settings.services.networking.headscale.shared.policy exit-nodes)
              );
            };
          };

          nginx.virtualHosts."${domain}" = {
            forceSSL = true;
            useACMEHost = environment.domain;
            locations = {
              "/" = {
                proxyPass = "http://localhost:${toString config.services.headscale.port}";
                proxyWebsockets = true;
              };
              "/metrics" = {
                proxyPass = "http://${config.services.headscale.settings.metrics_listen_addr}/metrics";
              };
            };
          };
        };

        # only_start_if_oidc_is_available: when kanidm runs here and a switch
        # restarts both, start only once kanidm reports ready (Type=notify).
        systemd.services.headscale.after = lib.optional config.services.kanidm.server.enable "kanidm.service";

        environment.systemPackages = [
          config.services.headscale.package
        ];
      };

    age-secrets =
      { environment, host, ... }:
      {
        age.secrets.headscale-oidc-secret = {
          rekeyFile = environment.secretPath + "/oidc/headscale-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          mode = "440";
          owner = "headscale";
          group = "headscale";
        };
      };

    firewall = {
      networking.firewall.allowedUDPPorts = udpPorts;
    };

    port-forwards =
      { environment, host, ... }:
      {
        environment = environment.name;
        name = "headscale-to-${host.name}";
        protocol = "udp";
        wanPort = portList;
        forward = {
          ip = environment.addressOn "default" host;
          port = portList;
        };
        allWans = true;
      };

    served-domains = { environment, host, ... }: environment.servedDomains host serviceDomains;

    persist = {
      directories = [
        "/var/lib/headscale"
      ];
    };

    prometheus-targets =
      { environment, host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit environment;
        exporters = [
          {
            job = "headscale";
            port = 8090;
          }
        ];
      };
  };
}
