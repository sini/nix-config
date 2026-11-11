# The one client helper for an environment's filtering resolvers
# (docs/dns-resolver.md §2.4). Every client path reads environment.dns.resolvers
# through it: networkd links and resolved's fallback (networking.nix), tailscale
# (accept-dns), headscale, the microvm guests and docker.
{ lib }:
rec {
  # The named instances' addresses in order, then the gateway (the fallback, (d)).
  # null when the environment names none: the consumer keeps its own list.
  # An instance with no running record fails evaluation; it is never dropped.
  resolversFor =
    {
      gateway ? true,
    }:
    environment: dns-resolvers:
    if environment.dns.resolvers == [ ] then
      null
    else
      map (
        n: (lib.findFirst (r: r.name == n) (throw "dns.resolvers: no instance ${n}") dns-resolvers).dns
      ) environment.dns.resolvers
      ++ lib.optional gateway environment.networks.default.gatewayIp;

  # The environment's upstreams as plain addresses (resolved's "#tls-name" dropped).
  plainUpstreams =
    environment: map (s: lib.head (lib.splitString "#" s)) environment.networks.default.dnsServers;

  # For a consumer that speaks plain DNS: the resolvers, else the plain upstreams.
  plainResolversFor =
    environment: dns-resolvers:
    let
      r = resolversFor { } environment dns-resolvers;
    in
    if r == null then plainUpstreams environment else r;

  # Owner Q13: a NixOS host leaves MagicDNS (accept-dns=false, its links on the
  # resolvers) when its environment names resolvers and it does not roam
  # (no core.network.manager). Roaming hosts keep MagicDNS.
  leavesMagicDns =
    manager: environment: host:
    environment.dns.resolvers != [ ] && !(host.hasAspect manager);
}
