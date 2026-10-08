# Opt-in: this host's nginx takes public ingress from the cluster gateway. The
# cluster joins this record with the host's served-domains by host name and
# routes each name to the endpoint (kubernetes.services.network.gateway.host-upstreams).
#
# Client IP: with `proxyProtocolPort` set, nginx also accepts PROXY v2 TLS on
# that port (from the environment's k3s nodes only) and restores the client
# address from the header; `proxyProtocol` then points the gateway at it.
# Roll out in that order: the listener first (inert), the record second.
{ den, lib, ... }:
{
  den.aspects.services.networking.gateway-upstream = {
    includes = [ den.aspects.services.networking.nginx ];

    settings = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "nginx plain TLS port the gateway forwards this host's names to when proxyProtocol is off";
      };
      proxyProtocolPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        example = 8444;
        description = "nginx TLS port that requires PROXY protocol, open to the environment's k3s nodes only; null for none";
      };
      proxyProtocol = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the gateway sends PROXY protocol v2 to proxyProtocolPort instead of plain TLS to port";
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
      assert lib.assertMsg (
        s.proxyProtocol -> s.proxyProtocolPort != null
      ) "${host.name}: gateway-upstream.proxyProtocol needs proxyProtocolPort (an nginx PROXY listener)";
      {
        environment = environment.name;
        host = host.name;
        address = environment.addressOn "default" host;
        port = if s.proxyProtocol then s.proxyProtocolPort else s.port;
        inherit (s) proxyProtocol exclude;
        # ponytail: passthrough only; "https" (terminate + BackendTLSPolicy) when a vhost wants L7 at Envoy.
        protocol = "tls-passthrough";
      };

    # The host's own served names resolve to loopback, so its local clients
    # (headscale's OIDC to idm, oauth2-proxy, grafana) reach nginx directly and
    # never depend on the public path or the cluster gateway.
    nixos =
      {
        config,
        environment,
        host,
        k3s-nodes,
        served-domains,
        ...
      }:
      let
        s = host.settings.services.networking.gateway-upstream;
        own = lib.unique (
          lib.concatMap (r: r.domains) (lib.filter (r: (r.host or null) == host.name) served-domains)
        );
        # The gateway's source address: Cilium masquerades pod egress outside
        # the pod CIDR to the node IP (measured: only node IPs reach nginx).
        nodes = lib.unique (map (n: n.ip) k3s-nodes);
        address = environment.addressOn "default" host;
      in
      lib.mkMerge [
        {
          networking.hosts = {
            "127.0.0.1" = own;
            "::1" = own;
          };
        }
        (lib.mkIf (s.proxyProtocolPort != null) {
          assertions = [
            {
              assertion = nodes != [ ];
              message = "${host.name}: gateway-upstream.proxyProtocolPort has no k3s nodes to trust";
            }
          ];
          # Every SSL vhost (and the `_` default_server) gains the PROXY listener;
          # the plain listens stay as defaultListenAddresses would give them.
          services.nginx.defaultListen =
            map (addr: { inherit addr; }) config.services.nginx.defaultListenAddresses
            ++ [
              {
                addr = address;
                port = s.proxyProtocolPort;
                ssl = true;
                proxyProtocol = true;
              }
            ];
          # realip only rewrites connections that carried a PROXY header, i.e. this
          # listener; the plain :443/:80 listens keep their peer address.
          services.nginx.appendHttpConfig = lib.concatLines (
            [ "real_ip_header proxy_protocol;" ] ++ map (ip: "set_real_ip_from ${ip};") nodes
          );
          # Not in allowedTCPPorts: anyone who can reach a PROXY listener can forge
          # client addresses.
          networking.firewall.extraInputRules = ''
            ip saddr { ${lib.concatStringsSep ", " nodes} } ip daddr ${address} tcp dport ${toString s.proxyProtocolPort} accept
          '';
        })
      ];
  };
}
