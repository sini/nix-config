# Blocky, the environment's filtering resolver, as a NixOS service
# (docs/dns-resolver.md §2.2). Included and gated by `isResolver` from the host
# file (the bgp pattern): the guard keys the collection policies
# (policies/blocky.nix) as well as this content, so including the aspect
# without the setting builds nothing.
#
# Blocky's settings come from this aspect's `render` setting; this instance supplies its LAN
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
      # The one Blocky definition (docs/dns-resolver.md §2.2): instance inputs to Blocky's
      # settings attrset, read by every instance (host.settings here, cluster.settings
      # in kubernetes/services/network/blocky.nix) and by the checks. Each instance
      # supplies only its listen addresses, its CoreDNS address and its list cache
      # directory.
      render = lib.mkOption {
        type = lib.types.functionTo lib.types.attrs;
        description = "Instance inputs -> Blocky's settings attrset.";
        default =
          let
            # resolved's "address#tls-name" to Blocky's DoT form, "tcp-tls:<ip>:853#<tls-name>".
            toBlockyUpstream =
              server:
              let
                parts = lib.splitString "#" server;
                ip = lib.head parts;
                host = if lib.hasInfix ":" ip then "[${ip}]" else ip;
              in
              "tcp-tls:${host}:853" + lib.optionalString (lib.length parts > 1) "#${lib.last parts}";
          in
          {
            upstreams,
            internalNames,
            internalResolver,
            tailnetDomain,
            cachePath,
            filter,
            dnsListen,
            httpListen,
          }:
          {
            upstreams = {
              strategy = "parallel_best";
              init.strategy = "fast";
              groups.default = map toBlockyUpstream upstreams;
            };
            # Unset, Blocky falls back to the OS resolver, which on a resolver host is Blocky itself.
            bootstrapDns = [ (toBlockyUpstream (lib.head upstreams)) ];
            conditional.mapping = lib.genAttrs internalNames (_: internalResolver) // {
              ${tailnetDomain} = "100.100.100.100";
            };
            blocking = {
              denylists.default = filter.denylists;
            }
            # An empty inline list renders "" and Blocky loads it as a file path.
            // lib.optionalAttrs (filter.allowlist != [ ]) {
              allowlists.default = [ (lib.concatLines filter.allowlist) ];
            }
            // {
              clientGroupsBlock.default = [ "default" ];
              # A positive answer, so a racing resolver's public answer can't displace it.
              blockType = "zeroIp";
              blockTTL = "1m";
              loading = {
                refreshPeriod = "4h";
                strategy = "fast";
                maxErrorsPerSource = 5;
                downloads = {
                  inherit cachePath;
                  # Per attempt, body read included; the 5s default truncates a multi-MB list on a slow WAN.
                  timeout = "60s";
                };
              };
            };
            caching.prefetching = true;
            queryLog.type = "console";
            prometheus.enable = true;
            # In-memory rolling 24h counters behind GET /api/stats, which the admin panel reads (§2.6).
            statistics.enable = true;
            ports = {
              dns = dnsListen;
              http = httpListen;
            };
          };
      };
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
            settings = host.settings.services.networking.blocky.render {
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
