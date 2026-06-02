{
  lib,
  config,
  ...
}:
let
  clusters = config.den.clusters or { };
in
{
  den.aspects.services.networking.haproxy = {
    nixos =
      {
        k3s-nodes,
        config,
        host,
        ...
      }:
      let
        # k3s hosts from collected pipe data (same-environment scoping
        # guaranteed by collect-k3s-nodes policy)
        k3sHostList = k3s-nodes;

        # Resolve k8s ingress VIP from the cluster's loadbalancer network
        envCluster =
          let
            matching = lib.filterAttrs (_: c: c.environment == host.environment) clusters;
            names = lib.attrNames matching;
          in
          if names != [ ] then matching.${lib.head names} else null;

        k8sIngressVip =
          if envCluster != null then
            envCluster.networks.kubernetes-loadbalancers.assignments.default-gateway
          else
            "10.11.0.1";
      in
      {
        # Port 12443 receives the public 443 (forwarded upstream) and splits
        # between local nginx (known SNI) and k8s ingress (everything else).
        services.haproxy = {
          enable = true;
          config = ''
            global
              log stdout format raw local0
              maxconn 4000

            defaults
              log global
              mode tcp
              option tcplog
              timeout connect 5s
              timeout client  1m
              timeout server  1m

            frontend fe_443
              bind *:12443
              tcp-request inspect-delay 5s
              tcp-request content accept if { req.ssl_hello_type 1 }

              acl sni_uplink req.ssl_sni -i ${
                lib.concatStringsSep " " (
                  lib.filter (name: name != "_" && name != "localhost") (
                    lib.attrNames config.services.nginx.virtualHosts
                  )
                )
              }

              use_backend be_local_nginx if sni_uplink
              default_backend be_k8s_ingress_443

            backend be_local_nginx
              # local nginx must be listening with TLS on this port
              server local 127.0.0.1:443

            backend be_k8s_ingress_443
              balance roundrobin
              option tcp-check
              server kube-vip ${k8sIngressVip}:443 check

            frontend kubernetes-api
              bind *:6443
              default_backend kubernetes-nodes

            backend kubernetes-nodes
              balance roundrobin
              option tcp-check
              ${lib.concatStringsSep "\n  " (map (n: "server ${n.hostname} ${n.ip}:6443 check") k3sHostList)}
          '';
        };
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [
        6443
        12443
      ];
    };
  };
}
