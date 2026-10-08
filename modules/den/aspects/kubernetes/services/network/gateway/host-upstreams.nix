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
      domainsOf =
        u:
        lib.subtractLists u.exclude (
          lib.concatMap (r: r.domains) (lib.filter (r: r.host or null == u.host) (inEnv served-domains))
        );
      nameOf = u: "${u.host}-nginx";
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
    in
    {
      gateways.default-gateway.spec.listeners = map listenerFor (lib.concatMap domainsOf upstreams);

      backends = perHost upstreams (u: {
        spec.endpoints = [
          {
            ip = {
              inherit (u) address port;
            };
          }
        ];
      });

      tlsRoutes = perHost upstreams (u: {
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
          hostnames = domainsOf u;
          rules = [
            {
              backendRefs = [
                {
                  group = "gateway.envoyproxy.io";
                  kind = "Backend";
                  name = nameOf u;
                  inherit (u) port;
                  weight = 1;
                }
              ];
            }
          ];
        };
      });

      # allow-gateway-world-egress admits world:443 only; each upstream's own
      # address:port (e.g. an nginx PROXY listener) is allowed explicitly.
      ciliumNetworkPolicies = lib.mapAttrs' (n: v: lib.nameValuePair "allow-gateway-${n}-egress" v) (
        perHost upstreams (u: {
          metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
          spec = {
            endpointSelector.matchLabels."gateway.networking.k8s.io/gateway-name" = "default-gateway";
            egress = [
              {
                toCIDR = [ "${u.address}/32" ];
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
            ];
          };
        })
      );

      backendTrafficPolicies = perHost (lib.filter (u: u.proxyProtocol) upstreams) (u: {
        spec = {
          targetRefs = [
            {
              group = "gateway.networking.k8s.io";
              kind = "TLSRoute";
              name = nameOf u;
            }
          ];
          proxyProtocol.version = "V2";
        };
      });
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
      failures = lib.runTests {
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
