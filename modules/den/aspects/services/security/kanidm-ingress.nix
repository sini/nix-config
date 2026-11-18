# A kanidm replica the cluster gateway routes the kanidm name to. The gateway
# terminates TLS on its HTTPS listener and re-encrypts to kanidmd (host-upstreams'
# "https" protocol), so it health-checks /status and sees HTTP. It publishes no DNS
# record: the name keeps its served-domains owner, and this host joins its route as a
# backend.
#
# kanidm keeps login and credential-update sessions in each server's memory
# (IdmServer.sessions), so the gateway pins a client to one replica with a cookie:
# one login never spans two servers, and every routed replica serves live traffic.
{
  den,
  lib,
  config,
  ...
}:
{
  den.aspects.services.security.kanidm-ingress = {
    includes = [ den.aspects.services.security.kanidm-server ];

    gateway-upstreams =
      { environment, host, ... }:
      {
        environment = environment.name;
        host = host.name;
        name = "${host.name}-kanidm";
        address = environment.addressOn "default" host;
        port = 8443;
        proxyProtocol = false;
        protocol = "https";
        exclude = [ ];
        domains = [ (environment.getDomainFor "kanidm") ];
        healthPath = "/status";
        affinityCookie = "idm-backend";
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
          # gateway.
          bindaddress = lib.mkForce "0.0.0.0:8443";
          # The client address from X-Forwarded-For, trusted only from the gateway's
          # sources: a pod address, or its node's when masqueraded, which between
          # axons is the Thunderbolt fabric loopback, else the management address.
          http_client_address_info.x-forward-for =
            lib.unique (
              map (n: n.ip) k3s-nodes ++ lib.filter (a: a != null) (map (n: n.fabricLoopback or null) k3s-nodes)
            )
            ++ [ cluster.networks.kubernetes-pods.cidr ];
        };
      };
  };
}
