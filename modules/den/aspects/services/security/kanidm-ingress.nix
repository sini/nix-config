# A kanidm replica the cluster gateway routes the kanidm name to, by TLS
# passthrough straight to kanidmd (no nginx). It publishes no DNS record: the name
# keeps its served-domains owner, and this host joins its route as a backend.
#
# kanidm keeps login and credential-update sessions in each server's memory
# (IdmServer.sessions), and passthrough gives envoy no cookie to stick on, so a
# replica serves as a fallback: it takes traffic only while the active backend
# fails its health checks, and one login never spans two servers.
{
  den,
  lib,
  config,
  ...
}:
{
  den.aspects.services.security.kanidm-ingress = {
    includes = [ den.aspects.services.security.kanidm-server ];

    settings.fallback = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Serve only while the route's active backend is unhealthy (see the file header). false makes this host an active backend.";
    };

    gateway-upstreams =
      { environment, host, ... }:
      {
        environment = environment.name;
        host = host.name;
        name = "${host.name}-kanidm";
        address = environment.addressOn "default" host;
        port = 8443;
        # As uplink's nginx: one route, one proxyProtocol (host-upstreams).
        proxyProtocol = true;
        protocol = "tls-passthrough";
        exclude = [ ];
        domains = [ (environment.getDomainFor "kanidm") ];
        inherit (host.settings.services.security.kanidm-ingress) fallback;
        node = true;
      };

    nixos =
      { host, k3s-nodes, ... }:
      let
        cluster = config.den.clusters.${host.settings.services.k3s.clusterName};
      in
      {
        services.kanidm.server.settings = {
          # Every address: loopback for local clients, the host address for the
          # gateway. A connection from a trusted source must open with a PROXY v2
          # header; any other is plain TLS.
          bindaddress = lib.mkForce "0.0.0.0:8443";
          # The gateway's source: a pod address, or its node's when masqueraded,
          # which between axons is the Thunderbolt fabric loopback (that route
          # sources from it), else the management address.
          http_client_address_info.proxy-v2 =
            lib.unique (
              map (n: n.ip) k3s-nodes ++ lib.filter (a: a != null) (map (n: n.fabricLoopback or null) k3s-nodes)
            )
            ++ [ cluster.networks.kubernetes-pods.cidr ];
        };
      };
  };
}
