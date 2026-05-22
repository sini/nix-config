{
  den,
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
  allHosts = config.den.hosts.x86_64-linux or { };
in
{
  den.aspects.services.haproxy = {
    nixos =
      {
        config,
        host,
        ...
      }:
      let
        env = environments.${host.environment};
        k3sHosts = lib.filterAttrs (
          _: h: h.environment == env.name && (h.settings.services.k3s or { }) != { }
        ) allHosts;
        k3sHostList = lib.attrValues k3sHosts;
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
              server kube-vip 10.11.0.1:443 check

            frontend kubernetes-api
              bind *:6443
              default_backend kubernetes-nodes

            backend kubernetes-nodes
              balance roundrobin
              option tcp-check
              ${lib.concatStringsSep "\n  " (
                map (h: "server ${h.name} ${builtins.head h.ipv4}:6443 check") k3sHostList
              )}
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
