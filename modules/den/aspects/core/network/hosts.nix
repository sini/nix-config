# Builds /etc/hosts and SSH known_hosts via pipe.collect.
#
# Emits host-addrs quirk with this host's address info; consumes
# collected entries from all peers to populate networking.hosts
# and services.openssh.knownHosts.
{
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.core.network.hosts = {
    # NOTE: host-addrs intentionally resolves the environment via the registry
    # closure rather than the parametric `environment` arg. The home-manager
    # extraction fans host aspects into the user scope (push-scope parent
    # fan-out), so this emit is re-fired at the user scope where `environment`
    # is not injected. The closure keeps the emit self-contained across scopes.
    # Proper fix (suppress host-class quirk emits during home-manager
    # extraction at the user scope) is flagged for the den engine — see
    # [[den_homemanager_quirk_reemit]].
    host-addrs =
      { host, ... }:
      let
        env = environments.${host.environment};
      in
      {
        hostname = host.name;
        domain = "${env.name}.${env.domain}";
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
