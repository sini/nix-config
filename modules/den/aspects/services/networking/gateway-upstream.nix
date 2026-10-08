# Opt-in: this host's nginx takes public ingress from the cluster gateway. The
# cluster joins this record with the host's served-domains by host name and
# routes each name to the endpoint (kubernetes.services.network.gateway.host-upstreams).
{ den, lib, ... }:
{
  den.aspects.services.networking.gateway-upstream = {
    includes = [ den.aspects.services.networking.nginx ];

    settings = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "nginx TLS port the gateway forwards this host's names to";
      };
      proxyProtocol = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the gateway prepends PROXY protocol v2 (the port must then be an nginx proxy_protocol listener)";
      };
      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "prometheus.json64.dev" ];
        description = "Served names (fqdns) the gateway does not route to this host: internal-only, reachable on the LAN and tailnet only";
      };
    };

    gateway-upstreams =
      { environment, host, ... }:
      let
        s = host.settings.services.networking.gateway-upstream;
      in
      {
        environment = environment.name;
        host = host.name;
        address = environment.addressOn "default" host;
        inherit (s) port proxyProtocol exclude;
        # ponytail: passthrough only; "https" (terminate + BackendTLSPolicy) when a vhost wants L7 at Envoy.
        protocol = "tls-passthrough";
      };

    # The host's own served names resolve to loopback, so its local clients
    # (headscale's OIDC to idm, oauth2-proxy, grafana) reach nginx directly and
    # never depend on the public path or the cluster gateway.
    nixos =
      { host, served-domains, ... }:
      let
        own = lib.unique (
          lib.concatMap (r: r.domains) (lib.filter (r: (r.host or null) == host.name) served-domains)
        );
      in
      {
        networking.hosts = {
          "127.0.0.1" = own;
          "::1" = own;
        };
      };
  };
}
