# Blocky, the environment's filtering resolver, as a NixOS service
# (docs/dns-resolver.md §2.2). Included and gated by `isResolver` from the host
# file (the bgp pattern): the guard keys the collection policies
# (policies/blocky.nix) as well as this content, so including the aspect
# without the setting builds nothing.
#
# Blocky's settings come from _settings.nix; this instance supplies its LAN
# address, the selected dns-internal record and its persisted list cache.
{ lib, ... }:
let
  inherit (lib) mkOption types;
  isResolver = host: host.settings.services.networking.blocky.isResolver or false;
  httpPortOf = host: host.settings.services.networking.blocky.httpPort or 4000;
  lanOf = environment: host: environment.addressOn "default" host;
  # The host's address in the LAN's ULA (prefix stripped), or null: stable where
  # the ISP-delegated prefix is not (docs/dns-resolver.md §2.4(a)).
  ulaOf =
    environment: host:
    let
      a = environment.ipv6On "default" host.ipv6;
    in
    if a == [ ] then null else lib.head (lib.splitString "/" (lib.head a));
  # Owned by the unit's DynamicUser; uplink wipes its root on boot.
  cacheDir = "/var/lib/private/blocky";
in
{
  den.aspects.services.networking.blocky = {
    settings = {
      httpPort = mkOption {
        type = types.port;
        default = 4000;
        description = "Blocky's HTTP port (API and metrics), on the LAN address and loopback";
      };
      isResolver = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this host runs its environment's Blocky resolver instance";
      };
    };

    nixos =
      {
        dns-internal,
        environment,
        host,
        served-domains,
        ...
      }:
      lib.mkIf (isResolver host) (
        let
          lan = lanOf environment host;
          ula = ulaOf environment host;
          httpPort = toString (httpPortOf host);
          internal =
            lib.findFirst (i: i.cluster == environment.dns.internal)
              (throw "environment.dns.internal = ${toString environment.dns.internal}: no cluster emits a dns-internal record for it")
              dns-internal;
        in
        {
          services.blocky = {
            enable = true;
            settings = import ./_settings.nix { inherit lib; } {
              upstreams = environment.networks.default.dnsServers;
              internalNames = lib.unique (
                lib.concatMap (r: r.domains) (lib.filter (r: r.environment == internal.environment) served-domains)
              );
              internalResolver = internal.address;
              tailnetDomain = "ts.${environment.domain}";
              cachePath = "/var/lib/blocky";
              inherit (environment.dns) filter;
              dnsListen = [ "${lan}:53" ] ++ lib.optional (ula != null) "[${ula}]:53";
              httpListen = [
                "${lan}:${httpPort}"
                # Alloy scrapes announced exporters on loopback.
                "127.0.0.1:${httpPort}"
              ];
            };
          };

          systemd.services.blocky = import ./_unit.nix;

          networking.firewall = {
            allowedTCPPorts = [
              53
              (httpPortOf host)
            ];
            allowedUDPPorts = [ 53 ];
          };
        }
      );

    cache =
      { host, ... }:
      lib.optionals (isResolver host) [
        {
          directories = [
            {
              directory = cacheDir;
              user = "nobody";
              group = "nogroup";
              mode = "0700";
            }
          ];
        }
      ];

    dns-resolvers =
      { environment, host, ... }:
      lib.optionals (isResolver host) [
        {
          name = host.name;
          environment = environment.name;
          dns = lanOf environment host;
          dns6 = ulaOf environment host;
          api = "http://${lanOf environment host}:${toString (httpPortOf host)}";
        }
      ];

    prometheus-targets =
      { environment, host, ... }:
      lib.optionals (isResolver host) [
        {
          hostname = host.name;
          ip = builtins.head host.ipv4;
          inherit environment;
          exporters = [
            {
              job = "blocky";
              port = httpPortOf host;
            }
          ];
        }
      ];
  };
}
