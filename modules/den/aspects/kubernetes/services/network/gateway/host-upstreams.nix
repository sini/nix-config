# Public names served by static hosts' nginx, routed by the default gateway:
# one TLS-passthrough listener per name, one envoy Backend + TLSRoute per host.
# Consumes the gateway-upstreams and served-domains quirks (joined by host);
# a name in the upstream's `exclude` gets no listener and no route.
#   nix build .#checks.x86_64-linux.gateway-host-upstreams
{ lib, ... }:
let
  render =
    {
      environment,
      gateway-upstreams,
      served-domains,
    }:
    let
      inEnv = lib.filter (r: r.environment == environment);
      upstreams = inEnv gateway-upstreams;
      # An upstream may name its domains itself (a replica that publishes no DNS
      # record of its own); otherwise they are its host's served-domains.
      domainsOf =
        u:
        lib.subtractLists u.exclude (
          u.domains
            or (lib.concatMap (r: r.domains) (lib.filter (r: r.host or null == u.host) (inEnv served-domains)))
        );
      nameOf = u: u.name or "${u.host}-nginx";
      # Fields the API server defaults are stated explicitly: Argo's predicted
      # state for these experimental-channel kinds omits them, so leaving them
      # out keeps the Gateway and TLSRoutes OutOfSync after every sync.
      gatewayGroup = "gateway.networking.k8s.io";
      listenerFor = d: {
        name = "tls-${lib.replaceStrings [ "." ] [ "-" ] d}";
        protocol = "TLS";
        port = 443;
        hostname = d;
        tls.mode = "Passthrough";
        allowedRoutes = {
          namespaces.from = "Same";
          kinds = [
            {
              group = gatewayGroup;
              kind = "TLSRoute";
            }
          ];
        };
      };
      perHost = us: f: lib.listToAttrs (map (u: lib.nameValuePair (nameOf u) (f u)) us);
      # A name served by several hosts (replicas) gets one listener and one route
      # whose backends are all of them: names are grouped by the hosts serving
      # them, one route per group. A one-host group keeps the host's own name.
      names = lib.unique (lib.concatMap domainsOf upstreams);
      routes = lib.foldl' (
        acc: d:
        let
          us = lib.filter (u: lib.elem d (domainsOf u)) upstreams;
          name =
            if lib.length us == 1 then nameOf (lib.head us) else lib.concatMapStringsSep "-" (u: u.host) us;
        in
        assert lib.assertMsg (lib.length (lib.unique (map (u: u.proxyProtocol) us)) == 1)
          "gateway-upstream: the hosts serving ${d} (${
            lib.concatMapStringsSep ", " (u: u.host) us
          }) disagree on proxyProtocol, which is set per route";
        assert lib.assertMsg (lib.any (u: !(u.fallback or false)) us)
          "gateway-upstream: every host serving ${d} (${
            lib.concatMapStringsSep ", " (u: u.host) us
          }) is a fallback; one must be active";
        acc
        // {
          ${name} = {
            upstreams = us;
            hostnames = (acc.${name}.hostnames or [ ]) ++ [ d ];
          };
        }
      ) { } names;
    in
    {
      gateways.default-gateway.spec.listeners = map listenerFor names;

      # A fallback backend takes traffic only while every non-fallback one of its
      # route is unhealthy: active/passive, for servers whose sessions are local.
      backends = perHost upstreams (u: {
        spec = {
          endpoints = [
            {
              ip = {
                inherit (u) address port;
              };
            }
          ];
        }
        // lib.optionalAttrs (u.fallback or false) { fallback = true; };
      });

      tlsRoutes = lib.mapAttrs (_: r: {
        spec = {
          # One unsectioned parent: the route attaches to every TLS listener whose
          # hostname it matches (the HTTPS listeners admit only HTTPRoute).
          parentRefs = [
            {
              group = gatewayGroup;
              kind = "Gateway";
              name = "default-gateway";
            }
          ];
          inherit (r) hostnames;
          rules = [
            {
              backendRefs = map (u: {
                group = "gateway.envoyproxy.io";
                kind = "Backend";
                name = nameOf u;
                inherit (u) port;
                weight = 1;
              }) r.upstreams;
            }
          ];
        };
      }) routes;

      # allow-gateway-world-egress admits world:443 only; each upstream's own
      # address:port (e.g. an nginx PROXY listener) is allowed explicitly.
      ciliumNetworkPolicies = lib.mapAttrs' (n: v: lib.nameValuePair "allow-gateway-${n}-egress" v) (
        perHost upstreams (u: {
          metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
          spec = {
            endpointSelector.matchLabels."gateway.networking.k8s.io/gateway-name" = "default-gateway";
            egress = [
              (
                # Cilium's CIDR rules never select cluster nodes, so a backend on a
                # node is reached by entity (any node, this port only).
                (
                  if u.node or false then
                    {
                      toEntities = [
                        "host"
                        "remote-node"
                      ];
                    }
                  else
                    { toCIDR = [ "${u.address}/32" ]; }
                )
                // {
                  toPorts = [
                    {
                      ports = [
                        {
                          port = toString u.port;
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              )
            ];
          };
        })
      );

      # Under passthrough envoy sees only TCP, so a shared name's backends are
      # checked by connect (active) and by connection failures (passive).
      backendTrafficPolicies =
        lib.mapAttrs
          (name: r: {
            spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "TLSRoute";
                  inherit name;
                }
              ];
            }
            // lib.optionalAttrs (lib.head r.upstreams).proxyProtocol { proxyProtocol.version = "V2"; }
            // lib.optionalAttrs (lib.length r.upstreams > 1) {
              healthCheck = {
                active = {
                  type = "TCP";
                  interval = "5s";
                  timeout = "2s";
                  unhealthyThreshold = 2;
                  healthyThreshold = 2;
                };
                passive = {
                  splitExternalLocalOriginErrors = true;
                  consecutiveLocalOriginFailures = 2;
                  interval = "5s";
                  baseEjectionTime = "30s";
                  maxEjectionPercent = 100;
                };
              };
            };
          })
          (lib.filterAttrs (_: r: (lib.head r.upstreams).proxyProtocol || lib.length r.upstreams > 1) routes);
    };
in
{
  den.aspects.kubernetes.services.network.gateway.host-upstreams = {
    k8s-manifests =
      {
        cluster,
        gateway-upstreams,
        served-domains,
        ...
      }:
      {
        applications.envoy-gateway-proxy.resources = render {
          inherit (cluster) environment;
          inherit gateway-upstreams served-domains;
        };
      };
  };

  # An excluded name gets no listener and no route; the host's other names and
  # other environments' records are unaffected.
  perSystem =
    { pkgs, ... }:
    let
      upstream = env: exclude: {
        environment = env;
        host = "h";
        address = "10.0.0.1";
        port = 443;
        proxyProtocol = false;
        protocol = "tls-passthrough";
        inherit exclude;
      };
      # A second host behind the gateway with PROXY v2 on its own port.
      proxied = upstream "e" [ ] // {
        host = "p";
        port = 8444;
        proxyProtocol = true;
      };
      served = env: {
        environment = env;
        host = "h";
        domains = [
          "a.x"
          "b.x"
        ];
      };
      out = render {
        environment = "e";
        gateway-upstreams = [
          (upstream "e" [ "b.x" ])
          (upstream "other" [ ])
          proxied
        ];
        served-domains = [
          (served "e")
          (served "other")
          (
            (served "e")
            // {
              host = "p";
              domains = [ "p.x" ];
            }
          )
          {
            environment = "e";
            cluster = "c";
            domains = [ "c.x" ];
          }
        ];
      };
      # Replicas: h and q both serve s.x; h also serves a.x alone.
      replicated =
        proxy:
        render {
          environment = "e";
          gateway-upstreams = [
            (upstream "e" [ ])
            (
              upstream "e" [ ]
              // {
                host = "q";
                address = "10.0.0.2";
                proxyProtocol = proxy;
              }
            )
          ];
          served-domains = [
            (
              served "e"
              // {
                domains = [
                  "a.x"
                  "s.x"
                ];
              }
            )
            (
              served "e"
              // {
                host = "q";
                domains = [ "s.x" ];
              }
            )
          ];
        };
      shared = replicated false;
      # A replica that names its domain, a fallback on a node: s.x routes to h
      # (active) and k (fallback, entity egress, health-checked).
      standby = render {
        environment = "e";
        gateway-upstreams = [
          (upstream "e" [ ])
          {
            environment = "e";
            host = "k";
            name = "k-kanidm";
            address = "10.0.0.3";
            port = 8443;
            proxyProtocol = false;
            protocol = "tls-passthrough";
            exclude = [ ];
            domains = [ "s.x" ];
            fallback = true;
            node = true;
          }
        ];
        served-domains = [
          (
            served "e"
            // {
              domains = [
                "a.x"
                "s.x"
              ];
            }
          )
        ];
      };
      allFallback = render {
        environment = "e";
        gateway-upstreams = [
          (upstream "e" [ ] // { fallback = true; })
          (
            upstream "e" [ ]
            // {
              host = "q";
              fallback = true;
            }
          )
        ];
        served-domains = [
          (served "e" // { domains = [ "s.x" ]; })
          (
            served "e"
            // {
              host = "q";
              domains = [ "s.x" ];
            }
          )
        ];
      };
      failures = lib.runTests {
        testSharedNameOneListener = {
          expr = map (l: l.hostname) shared.gateways.default-gateway.spec.listeners;
          expected = [
            "a.x"
            "s.x"
          ];
        };
        testSharedNameOneRouteAllBackends = {
          expr = lib.mapAttrs (_: r: {
            inherit (r.spec) hostnames;
            backends = map (b: b.name) (builtins.head r.spec.rules).backendRefs;
          }) shared.tlsRoutes;
          expected = {
            h-nginx = {
              hostnames = [ "a.x" ];
              backends = [ "h-nginx" ];
            };
            h-q = {
              hostnames = [ "s.x" ];
              backends = [
                "h-nginx"
                "q-nginx"
              ];
            };
          };
        };
        testStandbyRoute = {
          expr = map (b: b.name) (builtins.head standby.tlsRoutes.h-k.spec.rules).backendRefs;
          expected = [
            "h-nginx"
            "k-kanidm"
          ];
        };
        testStandbyFallbackOnlyOnReplica = {
          expr = lib.mapAttrs (_: b: b.spec.fallback or false) standby.backends;
          expected = {
            h-nginx = false;
            k-kanidm = true;
          };
        };
        testStandbyHealthChecked = {
          expr = lib.mapAttrs (_: p: [
            (p.spec.healthCheck.active.type or null)
            (p.spec ? proxyProtocol)
          ]) standby.backendTrafficPolicies;
          expected.h-k = [
            "TCP"
            false
          ];
        };
        testNodeEgressByEntity = {
          expr =
            (builtins.head standby.ciliumNetworkPolicies.allow-gateway-k-kanidm-egress.spec.egress)
              ? toEntities;
          expected = true;
        };
        testAllFallbackRefused = {
          expr = (builtins.tryEval (builtins.deepSeq allFallback.tlsRoutes null)).success;
          expected = false;
        };
        testSharedNameMixedProxyRefused = {
          expr = (builtins.tryEval (builtins.deepSeq (replicated true).tlsRoutes null)).success;
          expected = false;
        };
        testListenersSkipExcluded = {
          expr = map (l: l.hostname) out.gateways.default-gateway.spec.listeners;
          expected = [
            "a.x"
            "p.x"
          ];
        };
        testRouteSkipsExcluded = {
          expr = out.tlsRoutes.h-nginx.spec.hostnames;
          expected = [ "a.x" ];
        };
        testBackendPerHost = {
          expr = lib.attrNames out.backends;
          expected = [
            "h-nginx"
            "p-nginx"
          ];
        };
        # proxyProtocol: the route and backend use the upstream's port, a V2
        # BackendTrafficPolicy targets that route only, and egress admits it.
        testProxyPort = {
          expr = [
            (builtins.head out.backends.p-nginx.spec.endpoints).ip.port
            (builtins.head (builtins.head out.tlsRoutes.p-nginx.spec.rules).backendRefs).port
          ];
          expected = [
            8444
            8444
          ];
        };
        testProxyPolicyOnlyForProxied = {
          expr = lib.mapAttrs (_: p: {
            inherit (p.spec) targetRefs;
            inherit (p.spec.proxyProtocol) version;
          }) out.backendTrafficPolicies;
          expected.p-nginx = {
            targetRefs = [
              {
                group = "gateway.networking.k8s.io";
                kind = "TLSRoute";
                name = "p-nginx";
              }
            ];
            version = "V2";
          };
        };
        testEgressPerUpstream = {
          expr = lib.mapAttrs (
            _: p:
            let
              e = builtins.head p.spec.egress;
            in
            [
              e.toCIDR
              (builtins.head (builtins.head e.toPorts).ports).port
            ]
          ) out.ciliumNetworkPolicies;
          expected = {
            allow-gateway-h-nginx-egress = [
              [ "10.0.0.1/32" ]
              "443"
            ];
            allow-gateway-p-nginx-egress = [
              [ "10.0.0.1/32" ]
              "8444"
            ];
          };
        };
      };
    in
    {
      checks.gateway-host-upstreams =
        assert lib.assertMsg (failures == [ ]) "gateway-host-upstreams: ${builtins.toJSON failures}";
        pkgs.writeText "gateway-host-upstreams" "ok";
    };
}
