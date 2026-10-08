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
      listenerFor = d: {
        name = "tls-${lib.replaceStrings [ "." ] [ "-" ] d}";
        protocol = "TLS";
        port = 443;
        hostname = d;
        tls.mode = "Passthrough";
        allowedRoutes = {
          namespaces.from = "Same";
          kinds = [ { kind = "TLSRoute"; } ];
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
          parentRefs = [ { name = "default-gateway"; } ];
          hostnames = domainsOf u;
          rules = [
            {
              backendRefs = [
                {
                  group = "gateway.envoyproxy.io";
                  kind = "Backend";
                  name = nameOf u;
                  inherit (u) port;
                }
              ];
            }
          ];
        };
      });

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
        ];
        served-domains = [
          (served "e")
          (served "other")
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
          expected = [ "a.x" ];
        };
        testRouteSkipsExcluded = {
          expr = out.tlsRoutes.h-nginx.spec.hostnames;
          expected = [ "a.x" ];
        };
        testOneBackend = {
          expr = lib.attrNames out.backends;
          expected = [ "h-nginx" ];
        };
      };
    in
    {
      checks.gateway-host-upstreams =
        assert lib.assertMsg (failures == [ ]) "gateway-host-upstreams: ${builtins.toJSON failures}";
        pkgs.writeText "gateway-host-upstreams" "ok";
    };
}
