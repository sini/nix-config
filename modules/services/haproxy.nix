{ self, ... }:
let
  inherit (self.lib.host-utils) findHostsWithRole;
in
{
  flake.features.haproxy.nixos =
    {
      config,
      environment,
      lib,
      ...
    }:
    let
      hosts =
        findHostsWithRole "kubernetes"
        |> lib.attrsets.filterAttrs (hostname: hostConfig: environment.name == hostConfig.environment)
        |> lib.attrValues;
    in
    {
      # We fwd our public 443 to 12443 on this host since it has a 10gb link

      networking.firewall.allowedTCPPorts = [
        6443
        12443
      ];
      # TODO: Look into proxy protocol and socket based communication; this user config looks promising:
      # https://github.com/Bert-Proesmans/nix/blob/3da2d7d68617202d68e91575683ac4ba2ce718e7/flake/nixosConfigurations/freddy/tls-termination.nix#L126
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
              server kube-vip 10.11.0.2:443 check

            frontend kubernetes-api
              bind *:6443
              default_backend kubernetes-nodes

            backend kubernetes-nodes
              balance roundrobin
              option tcp-check
              ${
                (lib.concatStringsSep "\n  " (
                  map (host: "server ${host.hostname} ${builtins.head host.ipv4}:6443 check") hosts
                ))
              }
          '';
        };
      };
    };
}
