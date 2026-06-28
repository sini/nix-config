# Builds /etc/hosts + SSH known_hosts on NixOS and SSH known_hosts on Darwin,
# from a fleet-wide pipe.collect of host addresses.
#
# Emits the host-addrs quirk with this host's address info; consumes the
# collected entries from all peers. NixOS populates networking.hosts and
# services.openssh.knownHosts; Darwin has no comparable /etc/hosts story (and the
# LAN addresses are unreachable while roaming), so it only pins known_hosts by the
# tailnet name that `ssh <host>` resolves to (apps.dev.security.ssh aliases the
# short name to that tailnet name on darwin).
{
  den.aspects.core.network.hostsfile = {
    host-addrs =
      { environment, host, ... }:
      {
        hostname = host.name;
        domain = "${environment.name}.${environment.domain}";
        # Tailnet MagicDNS name — resolves on darwin (via the tailscale
        # /etc/resolver route) and on NixOS; the LAN forms don't, off-LAN.
        tsName = "${host.name}.ts.${environment.domain}";
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
              ++ (if entry.ipv4 == [ ] then [ entry.tsName ] else [ ]);
              inherit (entry) publicKeyFile;
            }
          ) peers
        );
      in
      {
        networking.hosts = hosts;
        services.openssh.knownHosts = knownHosts;
      };

    darwin =
      {
        host-addrs,
        config,
        lib,
        ...
      }:
      let
        peers = lib.filter (e: e.hostname != config.networking.hostName) host-addrs;
      in
      {
        # No /etc/hosts equivalent on darwin, and the LAN addresses are
        # unreachable while roaming, so `ssh <host>` connects via the tailnet
        # name (aliased in apps.dev.security.ssh). Pin each peer's host key under
        # that name (+ its others) so the connection verifies instead of
        # TOFU-prompting.
        programs.ssh.knownHosts = lib.listToAttrs (
          map (
            entry:
            lib.nameValuePair entry.hostname {
              hostNames = [
                entry.hostname
                entry.tsName
                "${entry.hostname}.${entry.domain}"
              ]
              ++ entry.ipv4;
              inherit (entry) publicKeyFile;
            }
          ) peers
        );
      };
  };
}
