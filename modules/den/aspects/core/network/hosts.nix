# Builds /etc/hosts and SSH known_hosts via pipe.collect.
#
# Emits host-addrs quirk with this host's address info; consumes
# collected entries from all peers to populate networking.hosts
# and services.openssh.knownHosts.
_: {
  den.aspects.core.network.hosts = {
    host-addrs =
      { environment, host, ... }:
      {
        hostname = host.name;
        domain = "${environment.name}.${environment.domain}";
        inherit (host) ipv4;
        publicKeyFile = host.public_key;
      };

    nixos =
      {
        host-addrs,
        config,
        lib,
        ...
      }:
      let
        peers = lib.filter (e: e.hostname != config.networking.hostName) host-addrs;

        hosts = lib.listToAttrs (
          map (
            entry:
            lib.nameValuePair (builtins.head entry.ipv4) [
              entry.hostname
              "${entry.hostname}.${entry.domain}"
            ]
          ) (lib.filter (e: e.ipv4 != [ ]) peers)
        );

        knownHosts = lib.listToAttrs (
          map (
            entry:
            lib.nameValuePair entry.hostname {
              hostNames = [
                entry.hostname
                "${entry.hostname}.${entry.domain}"
              ]
              ++ entry.ipv4
              ++ (if entry.ipv4 == [ ] then [ "${entry.hostname}.ts.json64.dev" ] else [ ]);
              inherit (entry) publicKeyFile;
            }
          ) peers
        );
      in
      {
        networking.hosts = hosts;
        services.openssh.knownHosts = knownHosts;
      };
  };
}
