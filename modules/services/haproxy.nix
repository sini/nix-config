{ self, ... }:
let
  inherit (self.lib.host-utils) findHostsWithRole;
in
{
  flake.features.haproxy.nixos =
    {
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
      services = {
        haproxy = {
          enable = true;
          config = ''
            global
              log stdout format raw local0
              maxconn 4000

            defaults
              mode tcp
              log global
              option tcplog
              timeout connect 5s
              timeout client 50s
              timeout server 50s

            frontend kubernetes-api
              bind *:6443
              default_backend kubernetes-nodes

            backend kubernetes-nodes
              balance roundrobin
              option tcp-check
          ''
          + (lib.concatStringsSep "\n" (
            map (host: "        server ${host.hostname} ${builtins.head host.ipv4}:6443 check") hosts
          ))
          + "\n"
          + ''
            frontend http_ing
              bind *:12080
              default_backend http_servers

            backend http_servers
              balance roundrobin
          ''
          + (lib.concatStringsSep "\n" (
            map (host: "        server ${host.hostname} ${builtins.head host.ipv4}:80 check") hosts
          ))
          + "\n"
          + ''
            frontend https_ing
              bind *:12443
              default_backend https_servers

            backend https_servers
              balance roundrobin
          ''
          + (lib.concatStringsSep "\n" (
            map (host: "        server ${host.hostname} ${builtins.head host.ipv4}:443 check") hosts
          ))
          + "\n";
        };
      };
    };
}
