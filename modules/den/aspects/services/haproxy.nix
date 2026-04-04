# HAProxy load balancer for Kubernetes API and ingress traffic.
#
# NOTE: This aspect uses host.environment.findHostsByFeature which depends on
# the old feature system's host discovery. The k3s feature filtering may need
# adjustment once k3s is migrated to den.
{ den, lib, ... }:
{
  den.aspects.haproxy = {
    includes = lib.attrValues den.aspects.haproxy._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
          # Find k3s hosts in the same environment
          k3sHosts = environment.findHostsByFeature "k3s" |> lib.attrValues;
        in
        {
          nixos =
            { config, ... }:
            {
              services = {
                haproxy = {
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
                      ${
                        (lib.concatStringsSep "\n  " (
                          map (h: "server ${h.name} ${builtins.head h.ipv4}:6443 check") k3sHosts
                        ))
                      }
                  '';
                };
              };
            };
        }
      );

      firewall = den.lib.perHost {
        firewall.allowedTCPPorts = [
          6443
          12443
        ];
      };
    };
  };
}
