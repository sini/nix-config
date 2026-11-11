# A local filtering DNS resolver (Blocky)

Status: **draft v0.5** (2026-11-10), revised against review rounds 1 to 4 and
two owner rulings (§8: Q13 decided, runtime blocklists). The review loop stopped
after round 4 by owner decision (objections per round: 14, 4, 7, 7), and the
phase-1 build follows. This is a design, not implemented. It is written against
`main` at `03b84230`. The owner's rulings are fixed: Blocky through the NixOS
`services.blocky` module, a `dns-filter` wrapper, the uplink → Kubernetes →
uplink-as-secondary phases, encrypted upstreams only, four client paths, and the
observability path. This document designs within them. Where a measurement
contradicts a ruling's premise, the section says so (§1, internal names).

## 1. Problem

Nothing filters DNS today, and the fleet's resolver configuration lives in five
places that disagree. Measured on 2026-11-10 over ssh, read-only:

**Fleet hosts resolve through the tailnet, not their LAN link.** On cortex,
`tailscale0` carries `DNS Domain: ts.json64.dev ~.` with `+DefaultRoute`
(headscale `override_local_dns = true`), and `br0` carries the environment's DoT
list (`+DNSOverTLS`, `1.1.1.1#cloudflare-dns.com` …), also with `+DefaultRoute`.
systemd-resolved routes a name to the links with its best-matching routing
domain, and `~.` matches every name. A `DefaultRoute` link without a routing
domain is asked only when no link's domain matches (`systemd-resolved(8)`,
"Protocols and Routing"). So `br0` is never asked while `tailscale0` carries
`~.`: on cortex, 40 of 40 queries answered from `link: tailscale0`, with "Data
was acquired via local or encrypted transport: no". The resolver a fleet host
actually uses is MagicDNS (`100.100.100.100`), which forwards to headscale's
`nameservers.global`, which is a hard-coded Cloudflare list.

**Five resolver lists:**

| Where                                                           | What                                                 | Transport                      |
| --------------------------------------------------------------- | ---------------------------------------------------- | ------------------------------ |
| `environments/{prod,dev}.nix` `networks.default.dnsServers`     | Cloudflare ×4, Quad9 ×2, `address#tls-name`          | DoT (`networking.nix:80-81`)   |
| `services/networking/headscale.nix:63-68` `nameservers.global`  | `1.1.1.1`, `1.0.0.1`, two Cloudflare v6              | tailscaled (DoH for known IPs) |
| `virtualization/docker.nix:27-30` `daemon.settings.dns`         | `8.8.8.8`, `1.1.1.1`                                 | plaintext                      |
| `hosts/uplink-dev.nix:135-138`, `hosts/cortex-cuda.nix:252-255` | `1.1.1.1`, `8.8.8.8` on the guest's `20-lan` network | plaintext                      |
| `kubernetes/.../coredns/coredns.nix:35-40` (fallback default)   | `1.1.1.1`, `8.8.8.8`                                 | plaintext                      |

Audit item D10 names the first three hard-coded lists. The cortex-cuda copy and
the CoreDNS fallback are the same defect. On uplink-dev, `resolvectl dns` shows
`enp0s9: 1.1.1.1 8.8.8.8 2001:5a8:608c:b600::1` with `-DNSOverTLS`, so the guest
sends plaintext queries to Google. cortex-cuda shows the same list. Google is in
no environment's list.

**IPv6 adds a sixth source.** Every `IPv6AcceptRA = true` link also takes the
router's RDNSS address: uplink's `br0` list ends in `2001:5a8:608c:b600::1`. A
LAN client that prefers IPv6 DNS asks the router directly.

**No filtering anywhere.** `dig @10.9.0.1 doubleclick.net` (the router) answers
`142.251.214.46`, and so does MagicDNS.

**Internal names: LAN clients get public answers today.** The ruling says LAN
clients should "keep getting internal answers". Measured, they don't get them
now:

- `dig @10.10.0.1`, `@10.9.0.1` (router) and `@100.100.100.100` (MagicDNS) for
  `grafana.json64.dev` and `idm.json64.dev` all answer the Cloudflare proxy
  addresses `172.67.162.75` and `104.21.57.89`.
- Only in-cluster pods get internal answers. CoreDNS's `hosts` plugin renders
  every prod `served-domains` record (`coredns.nix:23-31`), and CoreDNS's
  ClusterIP `172.21.0.10` is not reachable off-cluster. From cortex,
  `dig @172.21.0.10` times out. Cilium advertises only `ExternalIP` and
  `LoadBalancerIP` service addresses (`cilium-bgp-resources.nix:23-29`), so no
  ClusterIP is routed.
- The internal addresses themselves work from the LAN. From cortex (dev LAN),
  `curl --resolve grafana.json64.dev:443:10.11.0.1` returns 302 and
  `--resolve idm.json64.dev:443:10.10.10.1` returns 303.

Internal answers for LAN clients are therefore a new behaviour, not one to
preserve. §2.3 designs it, and §4 prices it.

**Port 53 on uplink:** only systemd-resolved's stubs (`127.0.0.53`,
`127.0.0.54`). `10.10.10.1:53` is free.

**Other facts the design depends on:**

- The tailnet holds 13 nodes (`headscale nodes list`). Three are mobile or
  roaming (`ipad`, `Open`, and `localhost` of user shuo) and leave the LAN. Of
  the den hosts, `blade` (NetworkManager) and the darwin hosts roam.
- The axons already run `tailscale set --accept-dns=false`
  (`services/k3s/node.nix:148-158`). On axon-01, `tailscale0` has no DNS
  servers, so `uplink.ts.json64.dev` is NXDOMAIN through resolved, while
  `host uplink.ts.json64.dev 100.100.100.100` answers `100.72.240.66`: quad-100
  keeps serving MagicDNS when the OS isn't pointed at it.
- The NixOS `blocky` unit `wants` `network-online.target` but has no `after` on
  it (nixpkgs `services/networking/blocky.nix:37-45`), and uplink has
  `net.ipv4.ip_nonlocal_bind = 0`. On uplink the LAN address comes from the
  initrd, not stage 2. Measured on 2026-11-10 from the current boot
  (`journalctl -b -o short-monotonic`, `systemctl show`):
  - the initrd's own networkd configures `10.10.10.1/16` on `br0`
    (`boot.initrd.systemd.network.networks.br0`), and `br0` gains carrier at
    12.06 s;
  - `boot.initrd.network.flushBeforeStage2` is `false` (both by capped
    `nix eval`), so the initrd's `KeepConfiguration` stays `dhcp-on-stop`
    (nixpkgs `networkd.nix:4275`) and the root switch at 23.60 s keeps the
    address;
  - stage 2 reaches `basic.target`, where `blocky` would start, at 25.73 s, and
    stage-2 networkd starts at 25.97 s;
  - at 26.48 s, tailscaled reports `br0` holding `10.10.10.1/16` together with
    the initrd's DHCPv6 lease `…::1e4` (acquired at 18.83 s). Stage-2 networkd
    drops that lease 3 ms later and takes its own, `…::271`, at 27.30 s.

  So the address stage 2 sees is the one the initrd set. Neither stage applies a
  static address before the link has carrier (review round 3, measured).

- tailscaled races every global nameserver (`net/dns/resolver/forwarder.go`,
  `forwardWithDestChan`), and the first success wins. A private address starts
  at once. A well-known public IP is upgraded to DoH, which also starts at once,
  and its plain-UDP leg is delayed by 500 ms.
- The pinned nixpkgs (`nixpkgs-master` `600291ca`, uplink's channel) ships
  `blocky` 0.35.0. Its module renders `settings` with `pkgs.formats.yaml` and
  runs `blocky validate` at build time (`enableConfigCheck`, default on). The
  unit runs with `DynamicUser` and `ProtectSystem = "strict"`. 0.35.0 has an
  on-disk list cache (`blocking.loading.downloads.cachePath`, §2.2). `blocky-ui`
  is not packaged.

## 2. Design

One shared Nix definition renders Blocky's YAML. A NixOS aspect and a Kubernetes
aspect both feed it, and each supplies only listen addresses, the CoreDNS
address and the list cache directory. An environment names its resolver
instances. Every client path (DHCP, static hosts and guests, headscale) reads
that one setting through one helper.

### 2.1 Den shape

| Piece                                       | Kind                | Holds                                                                                   |
| ------------------------------------------- | ------------------- | --------------------------------------------------------------------------------------- |
| `environment.dns.resolvers`                 | env option          | Ordered instance names (host or cluster). `[ ]` = today's behaviour                     |
| `environment.dns.filter`                    | env option          | `denylists`, `allowlist` (list URLs and inline domains): the same for every instance    |
| `environment.dns.internal`                  | env option          | Cluster whose `dns-internal` record is the conditional upstream (`"axon"`), or `null`   |
| `dns-internal` quirk                        | quirk               | `{ cluster; address; }`, emitted by the CoreDNS cluster aspect (§2.3)                   |
| `environment.networks.default.unifiNetwork` | env option          | The controller network name this environment's LAN is (`"Default"`, `"dev"`)            |
| `environment.networks.default.dnsServers`   | existing env option | Unchanged, and now **Blocky's upstreams** (§2.2)                                        |
| `dns-resolvers` quirk                       | quirk               | `{ name; environment; dns; api; }` per running instance; `environment` is the env name  |
| `services.networking.blocky`                | host aspect         | The NixOS service; emits `dns-resolvers` and `prometheus-targets`                       |
| `kubernetes.services.network.blocky`        | cluster aspect      | Phase 2 Deployment; emits `dns-resolvers`                                               |
| `services/networking/blocky/_settings.nix`  | helper              | The shared definition: a function from instance inputs to Blocky's settings attrset     |
| `core/network/_resolvers.nix`               | helper              | `resolversFor environment dns-resolvers` → addresses, then `networks.default.gatewayIp` |
| `services.networking.blocky.cli`            | host aspect         | `dns-filter`, built in the aspect because it needs den data (§2.5)                      |
| `core.network.tailscale`                    | existing aspect     | `--accept-dns=false` on non-roaming NixOS hosts (§2.4b)                                 |

This mirrors `monitoring.ingest`. The environment names an instance, and the
instance announces its own address through a quirk. No host file names another
host's address, and the resolver address lives where it already lives: uplink's
own host file (`networking.interfaces.enp4s0.ipv4`), read with
`environment.addressOn "default" host`. Fleet values stay out of aspects:

- the lists and upstreams are environment values;
- the address is a host value;
- the phase-2 load-balancer address is a cluster assignment.

The aspect's typed settings are instance-local only, with neutral defaults:

```nix
den.aspects.services.networking.blocky.settings = {
  httpPort = mkOption { type = types.port; default = 4000; };
  isResolver = mkOption { type = types.bool; default = false; };   # the resolver-host guard (below)
};
```

`environment.dns` already exists (`schema/environment.nix:326-341`, holding
`publicIPv4`), described as "The environment's public edge, for DNS records".
The three options join it, and its description widens to "The environment's DNS:
its public edge records, and the resolver instances, filter and internal
upstream its clients use (docs/dns-resolver.md)".

Phase 1 in the environment files, by rollout step (§2.9):

```nix
# step 1, prod.nix only: read by the resolver instance, which runs in prod
dns.internal = "axon";
dns.filter = {
  # hagezi's documented URL for its "Wildcard Asterisk" format, the one it names for Blocky
  denylists = [ "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt" ];
  allowlist = [ ];                 # inline domains, reviewed in the diff
};

# step 2, prod.nix and dev.nix (dev's hosts use prod's uplink; the quirk collects fleet-wide)
dns.resolvers = [ "uplink" ];

# step 3, prod.nix and dev.nix
networks.default.unifiNetwork = "Default";   # dev.nix: "dev"
```

`dns.internal` and `dns.filter` are set in prod only. Only a resolver instance
reads them, from its own environment, and both instances (uplink, then the axon
cluster) are in prod. In dev.nix they would be keys nothing reads.

And in `hosts/uplink.nix`: `includes = [ … services.networking.blocky ];` and
`settings.services.networking.blocky.isResolver = true;`, the way the same file
includes the Syncthing hub and sets `core.network.syncthing.isHub = true`
(`uplink.nix:44-46`, "the bgp pattern: the aspect declares the option, the host
file sets it").

**Collection.**

- `dns-resolvers` is emitted by a host (phase 1) and by a cluster (phase 2). A
  `collectAll` predicate matches only the entity kind it names, so every
  collecting scope declares two pipes, `({ host, ... }: true)` and
  `({ cluster, ... }: true)`, as `env-collect-dns` does for `served-domains`
  (`policies/pipes.nix:232-235`). The scopes are host (clients and
  `dns-filter`), cluster (CoreDNS's ingress policy, §2.3) and environment (the
  UniFi workspace). It holds one or two records.
- A `dns-resolvers` record's `environment` is the environment **name**, a
  string, for both kinds: a host record sets `environment = environment.name;`
  and the cluster record sets `environment = cluster.environment;`. A cluster
  entity exposes only the name (`environment` is `types.str`,
  `schema/cluster.nix:232-235`). Every consumer compares
  `r.environment == cluster.environment` (or `== environment.name`). That is the
  `served-domains` form: its host records carry `env.name`
  (`schema/environment.nix:211`), its cluster records the cluster's string
  (`schema/cluster.nix:197`), and CoreDNS filters them with that comparison
  (`coredns.nix:31`). The `prometheus-targets` form, `t.environment.name`
  (`prometheus.nix:63`), is not used: that record carries the environment
  entity, which a cluster record can't supply.
- `dns-internal` copies `monitoring-ingest`: the cluster emits it, a host policy
  `collect-dns-internal` collects it with `collectAll ({ cluster, ... }: true)`
  (as `pipes.nix:194-199` does), and the resolver host selects it with
  `lib.findFirst (i: i.cluster == environment.dns.internal) (throw "environment.dns.internal = ${toString environment.dns.internal}: no cluster emits a dns-internal record for it") dns-internal`
  (the `alloy.nix:20-21` selection, with `resolversFor`'s throw in place of
  `null`). An unset `dns.internal` (`null`) throws there too, so a resolver
  host's environment must name the cluster. The policy carries the resolver-host
  guard below, so only a resolver host collects it.
- The resolver host also needs the environment's `served-domains` (§2.3). Host
  scope collects none today, so a new host policy takes them.
- **The resolver-host guard** is keyed on the host running the instance, as
  `broadcast-hub-peer` is (`pipes.nix:299-305`):
  `{ host, ... }: lib.optionals (host.settings.services.networking.blocky.isResolver or false) [ … ]`.
  It is not keyed on `environment.dns.resolvers`: at rollout step 1 that list is
  `[ ]`, so uplink would collect nothing, and the `dns-internal` selection would
  throw. Every policy in `pipes.nix` keys on a setting (`:282`, `:292`, `:301`);
  none reads `host.hasAspect` (the only use in `policies/` is commented out,
  `clusters.nix:59`). The aspect's `nixos` content and its emits gate on the
  same setting, as `syncthing/hub.nix:62` gates on `isHub`, so the include and
  the setting can't disagree silently: including the aspect without the setting
  builds nothing.
- Every host does pay for `dns-resolvers` (two pipes, one or two records),
  `resolversFor` in `networking.nix`, and `dns-filter` from `roles.default`.
  That is a fleet-wide eval delta, admitted and priced on axon-01 by test 11.

### 2.2 Phase 1: the service on uplink

```nix
# services/networking/blocky/_settings.nix (sketch)
{ lib }:
{ upstreams, internalNames, internalResolver, tailnetDomain, cachePath, filter, dnsListen, httpListen }:
{
  upstreams = {
    strategy = "parallel_best";
    init.strategy = "fast";
    groups.default = map toBlockyUpstream upstreams;   # "1.1.1.1#cloudflare-dns.com" -> "tcp-tls:1.1.1.1:853#cloudflare-dns.com"
  };
  bootstrapDns = [ (toBlockyUpstream (lib.head upstreams)) ];
  conditional.mapping = lib.genAttrs internalNames (_: internalResolver)
    // { ${tailnetDomain} = "100.100.100.100"; };          # "ts.<domain>" -> quad-100 (§2.4b)
  blocking = {
    denylists.default = filter.denylists;                  # URLs (§2.2, Blocklists)
    # an empty inline list renders "" and loads as a file path; omit the key
  } // lib.optionalAttrs (filter.allowlist != [ ]) {
    allowlists.default = [ (lib.concatLines filter.allowlist) ];
  } // {
    clientGroupsBlock.default = [ "default" ];
    blockType = "zeroIp";
    blockTTL = "1m";
    loading = {
      refreshPeriod = "4h";
      strategy = "fast";             # serve at once; lists load in the background
      maxErrorsPerSource = 5;        # the default; a source stops parsing past it, keeping what it parsed
      downloads = {
        inherit cachePath;
        timeout = "60s";             # per attempt, body read included; the default 5s truncates the 4.9 MB list on a slow WAN
      };
    };
  };
  caching.prefetching = true;
  queryLog.type = "console";
  prometheus.enable = true;
  ports = { dns = dnsListen; http = httpListen; };
}
```

The NixOS aspect sets `services.blocky.settings` to this, with these instance
inputs:

- `dnsListen = [ "<lan>:53" ]` and
  `httpListen = [ "<lan>:4000" "127.0.0.1:4000" ]`, where `<lan>` is
  `environment.addressOn "default" host` (`10.10.10.1`).
- `internalResolver` is the selected `dns-internal` record's `address` (§2.1,
  §2.3).
- `tailnetDomain` = `"ts.${environment.domain}"`, the expression
  `headscale.nix:61` writes for `base_domain`. It is repeated, not factored: it
  is one interpolation, and `syncthing/hub.nix` already repeats it for its
  `.ts.` address (§2.4b).
- `cachePath = "/var/lib/blocky"`, the module's own `StateDirectory = "blocky"`
  (nixpkgs `blocky.nix:83`), which `DynamicUser` places at
  `/var/lib/private/blocky` under `ProtectSystem = "strict"` (§1). uplink wipes
  its root on boot, so the aspect declares
  `cache.directories = [ { directory = "/var/lib/private/blocky"; user = "nobody"; group = "nogroup"; mode = "0700"; } ]`,
  as `attic.nix:183-191` does for `/var/lib/private/atticd`.
- Boot: no ordering unit. On a normal boot, uplink's address is the initrd's and
  is already in place when stage 2 starts Blocky (§1). The case left is a boot
  where `br0` has no carrier (the switch is down). Then neither stage applies
  the address, and Blocky fails to bind `10.10.10.1` with `EADDRNOTAVAIL`. The
  module's `Restart = "on-failure"` retries at the default 100 ms, and the
  default start limit (5 starts in 10 s) would then leave it dead, with every
  client on the unfiltered gateway. So the aspect sets
  `serviceConfig.RestartSec = "2s"` and `startLimitIntervalSec = 0`, and Blocky
  retries every 2 s until the address appears. `ip_nonlocal_bind` would also
  work, but it is a host-wide sysctl and lets Blocky run on an address the host
  doesn't hold. Blocky's `ports.freeBind` is no substitute: it covers only the
  DNS and DoT listeners, not HTTP `:4000` (`server/server.go:232-259`). Test 5
  checks the guard in a VM.

The firewall opens TCP and UDP 53 and TCP 4000. Blocky binds only the IPv4 LAN
address, and the router forwards neither port, so nothing past the LAN reaches
them.

**Upstreams.** These are `networks.default.dnsServers`, unchanged: Cloudflare
and Quad9, already in `address#tls-name` form, rendered as DoT
(`tcp-tls:<ip>:853#<name>`, IPv6 bracketed). Blocky's upstream format is
`[net:]host[:port][/path][#commonName]`, so the certificate is still
authenticated by name. There is no new fleet value and no plaintext upstream.
The strategy is `parallel_best`: each query goes to two weighted-random
upstreams, and the faster answer wins. `strict`, the other strategy the ruling
names, is sequential failover. It never races, so it doesn't give the fastest
answer, and it isn't used. Upstreams given as IPs need no bootstrap. Blocky's
`bootstrapDns` is still pinned to the first upstream, because unset it falls
back to the OS resolver, and on uplink that is Blocky itself. It also resolves
the list host (`docs/configuration.md`, "Bootstrap DNS configuration"), so a
list download at boot doesn't wait on Blocky.

**Block answer: `zeroIp`, not NXDOMAIN.** After §2.4b, a fleet server has one
DNS path, so no link race remains there. The race that remains is on the tailnet
path for roaming devices: tailscaled races Blocky against a public DoH server
(§2.4c). An NXDOMAIN is a negative answer that a racer can discard in favour of
the other's positive public answer. `0.0.0.0` (or `::`) is a positive answer, so
it holds whichever rule the racer applies. `blockTTL = 1m`, down from the 6 h
default, so that `dns-filter off` reaches clients' caches within a minute.

**Blocklists: downloaded at runtime by URL** (owner ruling, v0.3). Updating a
list must not need a package build and a redeploy; AdGuard Home and Pi-hole
don't.

- The denylist is hagezi `pro` by its upstream URL,
  `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt`.
  hagezi's README documents this URL form, and its "Which format do I need?"
  table names "Wildcard Asterisk" for Blocky (v0.23 or newer). Measured on
  2026-11-10: `curl -I` answers HTTP 200 with an `etag` and
  `cache-control: public, max-age=604800, s-maxage=43200`, and the body is
  `*.<domain>` lines.
- Blocky refreshes every 4 h (`refreshPeriod = "4h"`). The refresh is a fixed
  ticker with no early retry after a failure (`config/config.go`,
  `SourceLoading.periodically`, at the 0.35.0 source).
- `strategy = "fast"`: Blocky serves DNS at once and loads lists in the
  background. A list error never stops the unit. A source that fails to
  download, or that yields no entries at all, fails only that refresh, and the
  group keeps the entries it already had (`lists/list_cache.go`, `refresh`:
  "using existing cache, if any"). A source that fails after yielding some
  entries does not fail: a body cut off mid-read, or one that passes
  `maxErrorsPerSource` parse errors, is kept as far as it parsed (`parseFile`,
  "If the file was partially parsed, we'll settle for that",
  `list_cache.go:360-373`), and that partial set replaces the group
  (`createCacheForGroup` fails only with no entries, `:223`). A truncated body
  is not written to the disk cache (`download_cache.go:226-243` discards the
  temp file on a read error), so the partial set lasts until the next good
  refresh or restart. `downloads.timeout` bounds each attempt, body read
  included (`http.Client.Timeout`, `downloader.go:78-81`), hence 60 s. Two
  alerts (below) catch a short list.
- `downloads.cachePath` is Blocky's on-disk list cache. With it, Blocky sends
  conditional requests (`If-None-Match`), serves a source from disk when its
  host is unreachable, and with `strategy = fast` seeds the lists from disk
  before the first download (`docs/configuration.md`, "Downloads";
  `seedFromDisk` in `lists/list_cache.go`). uplink persists the directory
  (above), so after the first successful download a restart or reboot starts
  filtered.

Costs, accepted with the ruling:

- The deployed list is not reviewed, and it is not in the closure. A bad
  upstream release is served until hagezi replaces it.
- Two instances may filter differently for up to one refresh period (§2.8).
- A start with no cached copy serves unfiltered until the first download
  completes, and for up to one refresh period if the list host is unreachable
  (§4).
- Freshness is the refresh period plus jsDelivr's edge cache (`s-maxage`, 12 h).

`blocky validate` does not open lists, so a build-time check
(`checks.<system>.blocky-lists`, test 9) asserts the sources are URLs, and a
runtime test (test 9) asserts a fresh download.

**Query log.** `queryLog.type = "console"` writes one line per query to stdout,
so to the journal. Alloy's existing `loki.source.journal` already ships every
unit with `unit="blocky.service"`. Nothing new is configured.

**Metrics.** The aspect emits a `prometheus-targets` record,
`{ hostname; ip; environment; exporters = [ { job = "blocky"; port = 4000; } ]; }`,
exactly as nginx and headscale do. Alloy scrapes each announced exporter on
`127.0.0.1:<port>` (`alloy.nix:50-61`) and remote-writes it to the axon ingest.
That is why the HTTP listener also binds loopback. The ruling's "LAN address
only" is read as "not on every interface, not the tailnet, not public". Loopback
adds no remote reach.

**Dashboard.** Blocky's own `docs/blocky-grafana.json` at tag `v0.35.0`
(HTTP 200) is added to `importedDashboards` in
`kubernetes/services/monitoring/grafana.nix`. It is pinned by URL and sha256,
with `fixDatasource = true`, in folder `Networking`. Query-log browsing is the
journal: a `mkLogsDashboard` entry over `{unit="blocky.service"}` with a
`$instance` variable.

**API.** `10.10.10.1:4000`, with no auth, per the owner's necessity pass: the
threat is low on the LAN, and the wrapper's default duration re-enables
filtering. §4 notes that the guarantee belongs to the wrapper, not to the API.

**Alerts.** Four rules in `kubernetes/services/monitoring/prometheus.nix`,
beside `HostSilent` in `additionalPrometheusRulesMap.hosts`, all
`severity = "warning"`. Their series arrive by the same path as test 6's
metrics. Alloy labels each scrape `job = "blocky"` (the announced job) and
`instance = host.name` (`alloy.nix:11-14`, `:46-61`).

- `BlockyDown`: one rule per host whose `prometheus-targets` record announces
  the `blocky` job, built as `HostSilent` builds its own from `expectedHosts`
  (`prometheus.nix:67-76`, `:216-225`).
  `expr = "absent_over_time(up{job=\"blocky\", instance=\"<host>\"}[5m]) or max_over_time(up{job=\"blocky\", instance=\"<host>\"}[5m]) < 1"`,
  `for = "5m"`. When Blocky is dead, its own series go stale and the three rules
  below can't fire. Alloy keeps pushing `up = 0` while the host runs, and the
  `absent_over_time` arm covers the host going silent.

- `BlockyFilteringOff`: `expr = "blocky_blocking_enabled == 0"`, `for = "15m"`.
  A disable longer than the wrapper's default, or an indefinite one through the
  raw API, pages.
- `BlockyDenylistShrunk`:
  `expr = "blocky_denylist_cache_entries{group=\"default\"} < 0.5 * max_over_time(blocky_denylist_cache_entries{group=\"default\"}[1d])"`,
  `for = "15m"`. A partial list (above) pages.
- `BlockyDenylistEmpty`:
  `expr = "blocky_denylist_cache_entries{group=\"default\"} == 0"`,
  `for = "15m"`. This covers a start with no cached copy (§4), which the 1-day
  max may not.

### 2.3 Internal names: conditional forwarding from den data

Blocky's `conditional.mapping` sends each **served name** to CoreDNS. The keys
are exactly the `domains` of the environment's `served-domains` records, from
both the host and the cluster kinds, filtered to the environment whose cluster
runs that CoreDNS. CoreDNS's own `hosts` plugin renders those same records
(`coredns.nix:23-31`), so both sides read one den source. Nothing hard-codes a
name, and the aspect source contains no `json64` literal (test 2).

The mapping is per name, not per zone (`json64.dev` itself is not mapped). The
consequences:

- A `json64.dev` name that no aspect serves resolves publicly, as today.
- A later change that has CoreDNS forward to Blocky can't loop, because CoreDNS
  answers every mapped name from `hosts` and never forwards one.
- A served name with only IPv4 gets an empty AAAA (`NOERROR`) from the `hosts`
  plugin, so no public AAAA leaks in.

**Reaching CoreDNS (phase 1).** The ClusterIP is unroutable (§1), so:

- `den.clusters.axon.networks.kubernetes-loadbalancers.assignments` gains
  `coredns-internal`, a fleet value in the cluster file.
- `coredns.nix` gains a `LoadBalancer` Service on it that selects the CoreDNS
  pods on UDP and TCP 53, with `externalTrafficPolicy = "Local"`, and emits the
  `dns-internal` record
  `{ cluster = cluster.name; address = cluster.getAssignment "coredns-internal"; }`,
  as `ingest.nix:24-31` emits `monitoring-ingest`. Cilium BGP-advertises it, and
  uplink, as the BGP hub, takes a per-address route, as it does for `10.11.0.10`
  through `10.11.0.31` today.
- `Local` is required, not a preference. CoreDNS runs on two of the three axons.
  Under the default `Cluster` policy every node advertises the address, and a
  query that lands on a node without a CoreDNS pod is SNATed to that node's
  address before it reaches the pod (the repo's own policies allow for this:
  `shoko.nix:340-343`, `hindsight.nix:974-979`), so it no longer matches the /32
  below and gets SERVFAIL. With `Local`, only nodes with a CoreDNS endpoint
  advertise, and uplink's source address is preserved. The repo's own
  LoadBalancers set it (`ingest.nix:123`, `smtp-relay.nix:177`,
  `llama-cpp.nix:220`, `searxng.nix:344`, `shoko.nix:273`, `hindsight.nix:587`),
  and review round 2 measured all 7 live LoadBalancers, the envoy gateway's
  included, at `Local`.
- `allow-kube-dns-cluster-ingress` gains a `fromCIDR` rule. Its addresses are
  the `dns-resolvers` records' addresses with
  `r.environment == cluster.environment` (§2.1), as /32s: only the resolver
  instances may query CoreDNS from outside the cluster.

**The router** is not a conditional upstream. It serves no internal names, and
measured, it returns the public answers. Listed beside CoreDNS, it would race
CoreDNS and return public answers nondeterministically. The ruling's "and/or" is
satisfied by CoreDNS alone.

**When the cluster is down,** a served name gets SERVFAIL from Blocky. This is
no worse than today. A host-served name's public path (`idm.json64.dev` →
Cloudflare → router DNAT → envoy gateway → `host-upstreams` → uplink nginx) also
crosses the cluster. §7 Q6 asks about the alternative.

### 2.4 Clients

**One helper.** `core/network/_resolvers.nix`:

```nix
resolversFor = { gateway ? true }: environment: dns-resolvers:
  if environment.dns.resolvers == [ ] then null   # null: the consumer keeps today's list
  else map (n: (lib.findFirst (r: r.name == n) (throw "dns.resolvers: no instance ${n}") dns-resolvers).dns)
         environment.dns.resolvers
       ++ lib.optional gateway environment.networks.default.gatewayIp;
```

The fallback is the environment's own gateway (prod `10.10.0.1`, dev `10.9.0.1`,
the same device), read from `gatewayIp`, which is already there.
`gateway = false` is for consumers that must not list it: (c) always, and (a) if
test 13 measures a leak. An instance name with no running instance fails
evaluation. It is not silently dropped.

**(a) LAN DHCP: the terranix `unifi` workspace.** `unifi.nix` renders, for each
environment that sets `networks.default.unifiNetwork`, a `restapi_object` on
that `rest/networkconf/<id>`, whose fields are:

- `dhcpd_dns_enabled = true`, and `dhcpd_dns_1..n` = `resolversFor` that
  environment, at most 4. DHCP clients don't fail over the way resolved does:
  some query every listed server in parallel or rotate through them, so the
  unfiltered gateway can win. Test 13 counts that from a DHCP phone and laptop.
  If either leaks, (a) uses `gateway = false` until phase 2 gives it a second
  filtering instance. The cost (§4) is no DNS for DHCP clients while uplink is
  down;
- the IPv6 RA and DHCPv6 DNS fields, set so that the router advertises no RDNSS
  of its own (§1). The exact field names are read from the live object first (§7
  Q4).

Today the networks are only read (`data.restapi_object.unifi_network_*`). Now
they are written:

- `unifi-adopt` imports each one by its `_id`;
- `ignore_server_additions = true` keeps drift on the declared fields only, as
  the NAT rules do;
- `lifecycle.prevent_destroy = true`, and its removal is a
  `removed { lifecycle { destroy = false } }` block, because a destroy of this
  resource would delete the LAN.

`checks.<system>.unifi-dhcp-dns-render` fixes the payload.

**(b) Static hosts and microvm guests.**

- **They leave MagicDNS** (owner Q13, decided: servers and microvm guests set
  `accept-dns=false` and use the LAN resolver; roaming devices keep MagicDNS).
  Today `tailscale0` carries `~.`, so resolved never asks `br0` (§1), and
  nothing below would take effect. `core.network.tailscale` adds
  `--accept-dns=false` to `extraSetFlags` on every NixOS host whose
  `resolversFor` is non-null and that does not include `core.network.manager`.
  It uses `extraSetFlags`, not `extraUpFlags`, for the reason
  `services/k3s/node.nix:143-147` gives: `up` runs only on first auth. The axons
  already do this (§1).
- **MagicDNS names resolve through Blocky.** Blocky's `conditional.mapping`
  sends `ts.<domain>` and its subdomains to `100.100.100.100` (§2.2), in the
  uplink instance and the phase-2 instance alike. quad-100 answers whether or
  not the OS points at it (measured on axon-01, §1), so a server needs no DNS
  state on `tailscale0` at all, and `*.ts.<domain>` reaches the tailnet answer
  over `br0`. `<domain>` comes from the same `ts.${environment.domain}`
  expression as `headscale.nix:61` (§2.2). The hop to quad-100 is plain DNS, but
  it never leaves uplink: tailscaled answers it in-process.
- **Why not a route on `tailscale0`.** A
  `resolvectl domain tailscale0 '~ts.<domain>'` oneshot (v0.2) doesn't hold.
  With `accept-dns=false`, tailscaled still applies an empty DNS config on every
  `SetDNS`, which resets the link's servers, domains and default route (review
  round 2, read from `net/dns/resolved.go`; how often it fires is UNVERIFIED),
  and its first `SetDNS` lands after the oneshot. Each tailscaled restart
  (`tailscale.nix:39-41`) clobbers it again. Unrouted, `*.ts.<domain>` falls to
  `br0` and the public zone, which answers NXDOMAIN for it today (measured
  2026-11-10 at the router and `1.1.1.1`, §4). The comment behind the hijack
  `services/k3s/node.nix:148-155` describes a public wildcard there: "MagicDNS
  pushes `search ts.json64.dev` into systemd-resolved; kubelet copies node
  search domains into every pod sandbox, where ndots:5 search-expands ~every
  external hostname through the CF-proxied `*.ts.json64.dev` wildcard —
  hijacking pod TLS cluster-wide". The Blocky mapping keeps both halves of that
  fix: no search domain reaches `resolv.conf` (no `accept-dns`), and the tailnet
  names still answer tailnet addresses, so the pinned `tsName` SSH paths
  (`hostsfile.nix`) keep working.
- **Why not `Domains=~.` on `br0`.** With `~.` on both links, both are the best
  match, and resolved sends every query to both in parallel
  (`systemd-resolved(8)`). The race would stay, MagicDNS's public tail could
  still win, and test 5 couldn't assert `link: br0`. `accept-dns=false` gives a
  server one path, and the axons already run it. A networkd `.network` for
  `tailscale0` is not used either: networkd doesn't manage that device today,
  and managing it risks the flushes `tailscale.nix:39-41` already works around.
- `networking.nix:80` reads `resolversFor`, falling back to `dnsServers` when it
  is `null`.
- With resolvers set, `DNSOverTLS = false` on that link. Blocky serves plain DNS
  on the LAN, and the router has no DoT. resolved's DoT mode is per link, so a
  strict DoT link can't list either. §4 prices the plaintext LAN hop.
- `ipv6AcceptRAConfig.UseDNS = false` and `dhcpV6Config.UseDNS = false`, so the
  list is exactly the environment's.
- `services.resolved.fallbackDns` is set to the same list. The compiled-in
  fallback (Google, Cloudflare, Quad9, measured in `resolvectl status`) applies
  only when no link has DNS, but it should not be Google.
- The guests' `20-lan` networks in `uplink-dev.nix` and `cortex-cuda.nix`, and
  `docker.nix`'s `daemon.settings.dns`, call the same helper, with `dnsServers`
  stripped of `#name` when it is `null`. No host includes
  `virtualization.docker` at `03b84230`, so the docker fix changes no closure.
- CoreDNS's literal fallback default goes too (`environment.networks.default` is
  required for a cluster's environment).

That closes D10 and the two copies D10 didn't list.

**Failback.** resolved may keep the router as a link's current server after a
failover. A failover can come from Blocky being down, and also from a SERVFAIL
that Blocky passes through: quad-100 during a tailscaled restart on uplink, a
served name while the cluster is down, or a DNSSEC-broken domain (§4). Whether
resolved rotates on a SERVFAIL is UNVERIFIED. Test 5 records the LAN link's
current server after each case.

The rule: if any of test 5's records shows the link's current server on the
gateway, the failback timer joins phase 1, in rollout step 2, before step 3.
Otherwise it is not built. Its minimal shape is in `core.network.networking`, on
the hosts that take `--accept-dns=false` (§2.4b): `resolversFor` non-null and no
`core.network.manager`. A NetworkManager host (`blade`) keeps MagicDNS and gets
no timer. The script finds the link at runtime from the default route. Den holds
no LAN-link name: a DHCP-only host has no static address to find it by, and a
guest's link is named by its PCI slot inside the guest (`enp0s9` on uplink-dev,
`enp0s12` on cortex-cuda, measured 2026-11-10).

```nix
# servers = resolversFor { } environment dns-resolvers; first = head servers
systemd.services.dns-failback = {
  serviceConfig.Type = "oneshot";
  path = [ config.systemd.package pkgs.dnsutils pkgs.gnugrep pkgs.iproute2 pkgs.gawk ];
  script = ''
    link=$(ip -o route show default | awk '{print $5; exit}')
    [ -n "$link" ] || exit 0                                                       # no default route yet
    resolvectl status "$link" | grep -q "Current DNS Server: ${first}$" && exit 0
    dig +time=2 +tries=1 @${first} example.com | grep -q "status: NOERROR" || exit 0   # still down
    resolvectl dns "$link" ${lib.escapeShellArgs servers}                          # re-set the same list
  '';
};
systemd.timers.dns-failback = {
  wantedBy = [ "timers.target" ];
  timerConfig = { OnBootSec = "5min"; OnUnitActiveSec = "5min"; };
};
```

That re-setting the same list moves the current server back to the first entry
is UNVERIFIED. The timer's own check is part of test 5. If it fails, the last
line becomes `systemctl restart systemd-resolved`.

**(c) headscale, for roaming devices.** After (b), only roaming devices use
MagicDNS: the three mobile nodes, `blade`, and the darwin hosts
(`tailscale/darwin.nix:67` keeps `--accept-dns=true`). Off-LAN filtering is
best-effort (owner Q13, decided). `nameservers.global` =
`resolversFor { gateway = false; }`, followed by the environment's `dnsServers`
addresses (with `#name` stripped, which tailscaled upgrades to DoH). The router
is excluded: it is a private address, so tailscaled would race it at once, and
it is unreachable off the LAN anyway. The public tail is there for the roaming
nodes (§1). Without it, an `ipad` off the LAN, or any tailnet-only client while
uplink is down, has no DNS at all, which is a regression from today. With it,
tailscaled races Blocky against DoH:

- On the LAN, Blocky's local answers (blocked names, internal names, cache hits)
  arrive in about a millisecond, against at least one DoH round trip. Blocky
  usually wins, but nothing guarantees it.
- Off the LAN, answers are unfiltered but encrypted, as today.

Test 1 counts the leak rate on the tailnet path, from `blade` on the LAN. §7 Q1
asks whether to drop the tail in phase 3, when two filtering instances exist.

**(d) Fallback.** This is the gateway, appended by `resolversFor` for (b), and
for (a) unless test 13 removes it. It is excluded from (c), for the reasons
given there.

### 2.5 `dns-filter`

A `writeShellApplication` (curl, jq), installed by
`services.networking.blocky.cli` and included by `roles.default`. Its instance
list is the `dns-resolvers` records' `api` URLs, baked in at build time.

| Command                | Action                                                                                    |
| ---------------------- | ----------------------------------------------------------------------------------------- |
| `dns-filter off [dur]` | `GET <api>/api/blocking/disable?duration=<dur>` on every instance; `dur` defaults to `5m` |
| `dns-filter on`        | `GET <api>/api/blocking/enable` on every instance                                         |
| `dns-filter status`    | `GET <api>/api/blocking/status` per instance: `enabled`, `autoEnableInSec`, one line each |

- `off` refuses `0` and any non-positive duration, because Blocky treats a
  missing duration as indefinite. `on` covers an early re-enable.
- It fans out sequentially and prints each instance's result. If any instance
  fails, it exits 1, and it never retries silently. A partial `off` leaves some
  clients filtered and some not. That is harmless, and it is reported.
- Blocky's disable state is in memory, so a restart also re-enables blocking.

### 2.6 blocky-ui: a later phase

Cut from phase 1 (review round 1). The design notes it carried move to §2.10
with the gates the review added.

### 2.7 Phase 2: Kubernetes replicas behind a load-balancer address

`kubernetes.services.network.blocky` calls the same `_settings.nix` with:

- `dnsListen = [ ":53" ]` and `httpListen = [ ":4000" ]`;
- `internalResolver` = the CoreDNS ClusterIP
  (`cluster.getAssignment "coredns"`), since the pods are in-cluster;
- `tailnetDomain` as in phase 1, so the pods also map `ts.<domain>` to
  `100.100.100.100`. That a pod reaches the node's quad-100 is UNVERIFIED (the
  axons run `--netfilter-mode=off`); test 14 checks it before the cutover;
- `cachePath = "/cache"`, an `emptyDir`: it survives a container restart, not a
  pod reschedule.

The rest:

- **Config:** `pkgs.formats.yaml` output in a ConfigMap. Its checksum is a pod
  annotation, so a config change, a list URL included, rolls the pods.
- **Image:** Nix-built (`dockerTools.streamLayeredImage` of `pkgs.blocky`), so
  the pod runs the same binary as phase 1. The lists are downloaded at runtime,
  as on uplink, so the image carries none.
- **Deployment:** 3 replicas, one per node (pod anti-affinity).
- **Service:** `LoadBalancer` on a new `blocky` assignment in
  `kubernetes-loadbalancers`, UDP/TCP 53 and TCP 4000, with
  `externalTrafficPolicy: Local`, so client addresses reach the query log and
  only nodes with an endpoint advertise.
- **CiliumNetworkPolicies:** ingress from `world` on 53, and from the `blocky`
  LB clients on 4000; ingress from `fromEntities = [ "host" "remote-node" ]` on
  53 and 4000, because the axons query their own LB first (§4, phase-2 boot
  ordering) and Cilium gives that traffic the `host` or `remote-node` identity,
  not `world` (the precedent is `tdarr.nix:454` and `cilium.nix:250`); egress to
  `world` on TCP 853 (upstreams) and TCP 443 (list downloads), and to
  `100.100.100.100/32` on 53 (tailnet names); and Prometheus on 4000. Egress
  from the blocky pods to the Redis pod on TCP 6379, and on the Redis side
  ingress on 6379 from the blocky pods only. Without that egress rule the
  replicas start, serve, and silently keep separate blocking state.
- **The `dns-resolvers` record:**
  `{ name = "axon"; environment = cluster.environment; dns = <blocky LB>; api = "http://<blocky LB>:4000"; }`.
  `environment` is the name string (§2.1), so the CoreDNS `fromCIDR` filter
  (§2.3) keeps this record.
- **Replica state:** `dns-filter` reaches one replica through the LB, so the
  replicas share blocking state through Blocky's `redis` option. Blocky
  documents that it "can synchronize its cache and blocking state between
  multiple instances". This needs a small in-cluster Redis or Valkey (§7 Q3).
  uplink stays a separate instance, and the wrapper fans out to both. Test 14
  checks the state per pod.
- **Metrics:** in-cluster Prometheus scrapes the pods (a ServiceMonitor), with
  the same `job="blocky"`, so the dashboard is unchanged. Pod stdout reaches
  Loki through the cluster's existing log collection.

Then `prod.nix`: `dns.resolvers = [ "axon" "uplink" ];`. That one line moves
DHCP, static hosts, guests and headscale.

### 2.8 Phase 3: uplink secondary

Nothing new. uplink's instance stays, second in `dns.resolvers`, and it keeps
`coredns-internal` as its internal resolver. Both instances render from one
definition at one commit and download the same list URLs, so they answer
identically except for up to one refresh period after a list release, when one
instance may hold the newer copy. A name added or removed in that window is the
only answer racing them (tailnet) or failing over between them (resolved, DHCP)
can change. The gateway stays the last resort.

### 2.9 Rollout

1. `_settings.nix`, the `services.networking.blocky` aspect with uplink
   including it and setting `isResolver = true`, `dns.internal = "axon"` and
   `dns.filter` in prod.nix (§2.1), the four alerts, and the `coredns-internal`
   LB, `dns-internal` record and policy. No client changes yet, since
   `dns.resolvers = [ ]`; the resolver-host guard is the setting, not that list
   (§2.1), so uplink already collects `served-domains` and `dns-internal`. Tests
   1–3, 6, 8 and 9 run against `@10.10.10.1` directly.
2. `dns.resolvers = [ "uplink" ]` in both environments, plus the (b) and (c)
   consumers (including `accept-dns=false`, owner Q13 decided) and the D10
   cleanup. Tests 5, 7 and 11. If test 5 shows a link on the gateway, the
   failback timer (§2.4) lands here, and test 5 reruns.
3. The UniFi DHCP and RA change (`unifi-plan`, reviewed, then `unifi-apply`).
   Tests 5 (DHCP client), 10 and 13. Test 13 decides whether the gateway stays
   in the DHCP list.
4. Phase 2 starts once tests 1–13 hold for a week, with §7 Q2 and Q3 answered.

### 2.10 Later phases

Cut from phase 1 by review round 1. Each is built only when its gate holds.

- **blocky-ui.** Not in nixpkgs (checked at `600291ca`). The image
  `ghcr.io/gabeduartem/blocky-ui` (MIT, port 3000, configured by
  `BLOCKY_UI_CONFIG`, no built-in auth) would run as a podman container on
  uplink at `127.0.0.1:3000`, behind nginx and oauth2-proxy as `homepage.nix`
  is. Two gates first:
  - The image bump is manual. `images/DESIGN.md` lists the automation as future
    ("Phase 2: Automation (Future)"), so nothing nightly would track it.
  - An `allowed_groups` gate on oauth2-proxy has no precedent in the repo, and
    Kanidm's `groups` claim may carry SPNs (`admins@idm.json64.dev`) rather than
    bare names, which would lock admins out. Measure the claim from a real token
    first, then land the gate with a check that the configured group string
    matches the measured claim form.
- **A failback timer** moves to phase 1 if test 5's records show a link on the
  gateway (§2.4, which gives its shape).
- **Test 9's phase-2 render equality.** Lands with phase 2, when the second
  renderer exists.

Each step is reversible by reverting its commit. `dns.resolvers = [ ]` restores
today's client lists exactly.

## 3. Acceptance

Each test has a control that must FAIL without the mechanism. A control that
passes means the test proves nothing.

1. **Blocking.** `dig @10.10.10.1 A <d>` and `AAAA <d>`, for a domain `<d>`
   taken from the list at its URL, answer `0.0.0.0` and `::` with TTL ≤ 60.
   `example.com` answers its real address.
   - Control: the same `<d>` at `@10.10.0.1` (the router) answers a routable
     address.
   - Tailnet path (roaming devices): on `blade`, on the LAN with MagicDNS,
     resolve 1000 list domains through `resolvectl query`, and count the answers
     that aren't `0.0.0.0`. Record the leak rate (§2.4c). The same run with
     `dns.resolvers = [ ]` must leak 1000 of 1000.
2. **Internal names.**
   - For every name in prod's `served-domains` (from `nix eval` of the
     collection, capped), `dig @10.10.10.1` returns that record's `address`.
   - A `json64.dev` name no aspect serves returns its public answer.
   - `rg json64 modules/den/aspects/services/networking/blocky` returns 0 lines,
     while the rendered YAML contains `grafana.json64.dev`.
   - Control: the router returns `172.67.162.75` and `104.21.57.89` for
     `grafana.json64.dev` (measured in §1).
3. **Encrypted upstream.** On uplink, with no `acme-*` unit active:
   - Run 500 uncached random names through `@10.10.10.1`, while
     `tcpdump -ni br0 'port 53 and not dst net 10.0.0.0/8'` captures 0 packets
     and `tcpdump -ni br0 'tcp port 853'` captures more than 0.
   - Control: the same port-53 capture during a `dig @1.1.1.1 example.com` on
     uplink catches the query, so the filter sees plaintext when there is some.
   - lego's DNS-01 propagation checks are a known exception
     (`acme.dnsResolver = "1.1.1.1:53"` and authoritative NS queries), so the
     test excludes renewal windows.
4. **`dns-filter off 5m` re-enables itself.**
   - `dns-filter off` with no argument: `status` reports `enabled=false` and
     `autoEnableInSec` between 290 and 300 on every instance, and the test `<d>`
     resolves to its real address at `@10.10.10.1`.
   - At t+310 s, `<d>` is `0.0.0.0` again and `status` reports `enabled=true`,
     with no `on` issued.
   - Control: `dns-filter off 0` exits non-zero and leaves blocking enabled.
     During the window, `<d>` is not `0.0.0.0` (so `off` worked).
5. **One path, and the fallback while the resolver is down.** Each host's LAN
   link is the one carrying its default route,
   `ip -o route show default | awk '{print $5; exit}'`, the lookup the failback
   timer uses (§2.4): `br0` on cortex and uplink, `enp2s0` on axon-01, `enp0s9`
   on uplink-dev and `enp0s12` on cortex-cuda (measured 2026-11-10).
   - With Blocky up, `resolvectl query example.com` on cortex, uplink-dev,
     cortex-cuda and axon-01 answers `-- link: <lan>`. Control: at `03b84230`,
     cortex answers from `link: tailscale0` (40 of 40, §1).
   - Tailnet names survive tailscaled: on cortex and axon-01, run
     `systemctl restart tailscaled`, wait for `tailscale status` to report the
     node online, then `resolvectl query uplink.ts.json64.dev` answers
     `100.72.240.66` (a tailnet `100.64.0.0/10` address) from the LAN link, and
     `dig @10.10.10.1 uplink.ts.json64.dev` answers the same. Control: rendered
     without the `ts.<domain>` mapping, `dig @10.10.10.1 uplink.ts.json64.dev`
     answers no `100.64.0.0/10` address.
   - SERVFAIL on uplink's side (a record, deciding the failback timer, §2.4).
     Before each query below, flush Blocky's response cache with
     `curl -X POST http://10.10.10.1:4000/api/cache/flush` (0.35.0
     `docs/interfaces.md`), and query with `resolvectl query --cache=no`. Then
     neither resolved's cache nor Blocky's (which prefetches) answers in the
     upstream's place. On cortex, record each answer and
     `resolvectl status br0`'s `Current DNS Server`:
     - `gone.ts.json64.dev`, a tailnet name that doesn't exist, which quad-100
       answers SERVFAIL in steady state (§4);
     - `uplink.ts.json64.dev`, once a second through a
       `systemctl restart tailscaled` on uplink and once 60 s after it;
     - `dnssec-failed.org`.
   - Stop `blocky.service` on uplink. Then `resolvectl query example.com`
     succeeds on the same hosts, still from the LAN link, and on a LAN DHCP
     client after step 3 if test 13 kept the gateway. Repeat with uplink powered
     off, which also removes headscale.
   - Control: on cortex, with the link temporarily set to
     `resolvectl dns br0 10.10.10.1` (no fallback), the query fails, so the
     earlier success came through the fallback and not through `tailscale0`.
   - Failback: start Blocky again and record each host's current server after 10
     min. This is a record, not a gate. With the two SERVFAIL records above, it
     decides the failback timer (§2.4). If the timer is built: on cortex, with
     the current server on the gateway and Blocky up, `Current DNS Server` is
     `10.10.10.1` within 10 min. Control: with the timer stopped, it stays on
     the gateway.
   - Boot without the address (§2.2), a NixOS VM test: the VM's LAN bridge has
     no port at boot, and a oneshot adds its only port 10 s later, so the
     address arrives after Blocky's first start. With the aspect's `RestartSec`
     and `startLimitIntervalSec`, `blocky.service` is active, answers on the
     bridge address within 15 s of the port being added, and `NRestarts` is at
     least 1, which shows the test hit the race. Control: with both keys
     removed, Blocky fails with `EADDRNOTAVAIL` and ends `failed` with result
     `start-limit-hit`. A reboot of uplink is not a test: there the address is
     the initrd's (§1), so it passes with or without the guard.
6. **Metrics and logs arrive.**
   - In Prometheus, `up{job="blocky", instance="uplink"} == 1`, and
     `blocky_blocking_enabled` is present.
   - In Loki, `{unit="blocky.service"} |= "<uuid>.example.com"` returns the
     query within 2 min of resolving it.
   - The dashboard's panels are non-empty.
   - Controls: a second, never-queried uuid returns 0 lines. With
     `blocky.service` stopped, `up` goes to 0 within two scrape intervals, and
     `BlockyDown` fires in Alertmanager between 10 and 12 min after the stop (5
     min of `max_over_time` plus `for = 5m`).
   - Alert: `dns-filter off 20m` makes `BlockyFilteringOff` fire in Alertmanager
     between 15 and 17 min. Control: `dns-filter off 5m` never fires it.
7. **D10 is gone.** `rg -n '"(8\.8\.8\.8|1\.1\.1\.1|1\.0\.0\.1)"' modules/den`
   matches nothing outside the environment files' `dnsServers` and
   `acme.dnsResolver`. Control: at `03b84230`, the same command matches the five
   sites in §1.
8. **API exposure.**
   - `ss -ltn` on uplink shows `:4000` bound only on `10.10.10.1` and
     `127.0.0.1`, and `:53` only on `10.10.10.1`.
   - `curl http://10.10.10.1:4000/api/blocking/status` from cortex returns 200.
   - `curl http://100.72.240.66:4000/…` (uplink's tailnet address) is refused.
   - Control: the same curl against `10.10.10.1` succeeds, so the refusal is the
     bind, not a dead service.
9. **Lists.** `blocky validate` runs in `system.checks`, but it does not open
   lists.
   - Sources are URLs: `checks.<system>.blocky-lists` asserts, at evaluation and
     with no network, that every rendered `denylists` entry and every
     `allowlists` entry that is not inline (has no newline) starts with
     `https://`. Control: a denylist entry `wildcard/pro.txt` (a bare path)
     fails `blocky-lists`, while `blocky validate` alone passes it.
   - A fresh download: stop Blocky on uplink, empty `/var/lib/private/blocky`,
     and start it. Within 5 min, read from `127.0.0.1:4000/metrics`,
     `blocky_failed_downloads_total` is `0` and
     `blocky_denylist_cache_entries{group="default"}` is above 0 (both 0.35.0
     names, `metrics/metrics_event_publisher.go:89,153`), and
     `journalctl -u blocky --since <the start>` holds a `group import finished`
     line (`lists/list_cache.go:174`, logged only by a refresh, not by the disk
     seed) and an `import succeeded` line (`list_cache.go:376`). A body cut off
     mid-read skips `import succeeded`: its parse error returns early
     (`:359-373`), yet the group still imports and the counter stays 0. The
     cache file named by the URL's sha256,
     `/var/lib/private/blocky/$(printf %s '<url>' | sha256sum | cut -d' ' -f1)`
     (`cacheFilePath`, `download_cache.go:16-21`), exists. It is renamed into
     place only once the body has been read to EOF (`:146-170`, `:225-243`). A
     gauge above 0 alone would pass on a dead URL once the disk cache exists,
     because `seedFromDisk` fills the group first (`list_cache.go:99-100`).
   - A 404 is not served from the cache. This is the control for the
     fresh-download assertions above, and it runs in a NixOS VM, because the
     cache is keyed by URL, so only the same URL can be seeded. A local HTTP
     server serves the denylist at one URL, first with 200: Blocky loads it, and
     the cache file exists. Then the server answers 404 for that URL, and Blocky
     restarts. The gauge still reads above 0 (seeded from disk), but
     `blocky_failed_downloads_total` is above 0, and no `group import finished`
     or `import succeeded` line follows the restart. A 404 is not served from
     the cache (`download_cache.go:87-99`), and the group keeps its seeded
     entries.
   - A dead list does not stop startup: a NixOS VM test whose denylist is a
     bogus URL (`https://127.0.0.1:9/none.txt`) reads 0 for the gauge, while
     `blocky.service` is active with `NRestarts` 0 and port 53 answers.
   - A short list alerts: a VM test serves the list from a local HTTP server,
     first whole, then cut off mid-body. After the second refresh the gauge
     reads the partial count, below half the first, and `BlockyDenylistShrunk`'s
     expression holds. Control: served whole both times, the gauge doesn't drop
     and the expression is false.
   - Empty allowlist: with `allowlist = [ ]`, the rendered YAML has no
     `allowlists` key, and the same VM test logs no `could not init allowlist`
     line. Control: forcing `allowlists.default = [ "" ]` logs it (under
     `strategy = fast` the unit stays up, so the log line is the signal).
   - The phase-2 render-equality check moves to phase 2 (§2.10).
10. **No RDNSS bypass.** After step 3, a LAN phone's and laptop's DNS list holds
    only `resolversFor` and the gateway, with no `2001:5a8:…::1`. Control:
    before step 3, the same device lists the router's IPv6 address.
11. **Evaluation cost.** Measure uplink's and axon-01's evaluation time and peak
    memory before and after rollout steps 1 and 2 (capped at 12G, same machine,
    three runs).
    - axon-01 moves, by design: every host collects `dns-resolvers`, calls
      `resolversFor` and installs `dns-filter` (§2.1). Its delta is reported as
      an explicit admission, with the numbers.
    - Only uplink collects `served-domains` and `dns-internal`. axon-01's
      collected `served-domains` and `dns-internal` are empty (`nix eval`,
      capped), and uplink's are not. Control: removing the resolver-host guard
      makes axon-01's non-empty.
12. **Cross-environment reach.** `dig @10.10.10.1 example.com` from cortex (dev
    LAN, through the router) answers. Control: with port 53 closed in uplink's
    firewall, it times out.
13. **DHCP clients don't race to the gateway.** After step 3, on a DHCP phone
    and a DHCP laptop (OS resolver, browser DoH off), resolve 200 list domains
    and count the answers that aren't `0.0.0.0`. Any leak on either device means
    (a) drops the gateway (`gateway = false`) until phase 2. Control: with
    `dhcpd_dns_1` set to the gateway alone, the same run leaks 200 of 200.
14. **Phase 2: shared blocking state, and the axons reach their own LB.**
    - `dns-filter off 5m` through the LB, then `GET /api/blocking/status` on
      each pod IP from a node: every pod reports `enabled=false`. Control: with
      the Redis egress rule removed, only the pod the LB picked reports
      `enabled=false`.
    - On axon-01, after `dns.resolvers = [ "axon" "uplink" ]`:
      `resolvectl query <uuid>.example.com` succeeds, `resolvectl status enp2s0`
      (axon-01's LAN link, test 5) shows the `blocky` LB address as
      `Current DNS Server`, and the uuid appears in a blocky pod's log, not in
      uplink's journal. Control: with the `host`/`remote-node` ingress rule
      removed, the query is slow, the current server moves to uplink, and the
      uuid appears in uplink's journal.
    - From a blocky pod, `uplink.ts.json64.dev` resolves to `100.72.240.66`
      (§2.7, quad-100 from a pod). Control: with the `100.100.100.100/32` egress
      rule removed, the same query answers SERVFAIL.

## 4. Risks

- **A plaintext LAN hop.** Today, a host's `br0` link speaks strict DoT to
  Cloudflare. After the change it speaks plain DNS to Blocky, and Blocky speaks
  DoT out. The ISP sees nothing either way, but a LAN attacker sees host
  queries. Accepted under the owner's necessity pass. Serving DoT on the LAN is
  a non-goal (§6).
- **The tailnet race (§2.4c).** Filtering on the tailnet path is best-effort
  while the public DoH tail stays. After §2.4b only roaming devices take that
  path. Test 1 measures it.
- **Servers leave MagicDNS (owner Q13, decided).** A server resolves tailnet
  names only through a filtering instance's `ts.<domain>` mapping (§2.4b).
  - While no instance answers, those names fall to the gateway. The gateway and
    `1.1.1.1` answer NXDOMAIN for `*.ts.json64.dev`, existing nodes included,
    with Cloudflare's SOA (measured 2026-11-10). The CF-proxied wildcard that
    `node.nix:151` describes doesn't answer.
  - The SERVFAIL case. With `accept-dns=false`, quad-100 answers SERVFAIL for a
    nonexistent `ts.` name and for a non-`ts.` name such as `example.com`; a
    real node gets its A record, and AAAA is NOERROR and empty. That was
    measured on axon-01 at tailscale 1.104.1 (review round 3), and may change
    with the version. During a tailscaled restart on uplink (8 Started or
    Stopping lines in 14 days), every `ts.` query fails. Blocky passes an
    upstream SERVFAIL through as SERVFAIL
    (`resolver/upstream_resolver.go:432-440`, `server/server.go:853-857`), and
    resolved may then rotate the link to the gateway and stay there (UNVERIFIED;
    axon-01's current server is already `1.0.0.1`, the third in its list, so a
    rotation does stick). The same holds for served names while the cluster is
    down and for DNSSEC-broken domains. Blocky 0.35.0 has no key that maps an
    upstream SERVFAIL to another answer: `conditional.mapping` takes only
    upstream lists (`config/conditional_upstream.go`), so nothing is configured.
  - Either way, `ssh` to a `tsName` fails until Blocky or quad-100 answers,
    which breaks peer-sync's BatchMode paths (`hostsfile.nix:63-73`) for that
    window. LAN names (`/etc/hosts`, `hostsfile.nix`) still work. Test 5 checks
    the mapping across a tailscaled restart, records the server after a
    SERVFAIL, and decides the failback timer (§2.4).
- **An upstream list is unreachable at boot.** `strategy = fast` starts serving
  at once. With a cached copy (uplink, after its first successful download), the
  lists seed from disk first, so there is no unfiltered window. With no cached
  copy (uplink's first start, a wiped cache, or a rescheduled phase-2 pod, whose
  `emptyDir` is new), Blocky serves with an empty denylist until a download
  succeeds. The refresh is a fixed 4 h ticker with no early retry (§2.2), so the
  window is up to 4 h, plus 3 download attempts. `BlockyDenylistEmpty` pages
  after 15 min of it (§2.2), and test 9 reads the gauge.
- **A truncated list download** replaces the group with the partial set and
  lasts until the next good refresh (§2.2). The 60 s `downloads.timeout` makes
  it rarer, and `BlockyDenylistShrunk` pages on it.
- **DHCP without the gateway.** If test 13 drops the gateway, DHCP clients have
  no DNS while uplink is down, until phase 2.
- **Fallback privacy.** In fallback, clients use the router, and the router's
  own upstream is whatever its WAN DNS is, likely the ISP in plaintext (§7 Q5).
- **Internal answers are new for LAN clients (§1).** A served name now resolves
  to a host's LAN IP or to the gateway VIP `10.11.0.1`. From the dev LAN this
  works (measured). From the prod LAN (`10.10.0.0/16`), a client that shares the
  subnet with the axon nodes, reaching a VIP through the router, is the
  asymmetric path `uplink-dev.nix` measured on 2026-11-09: the SYN goes through
  the gateway, the node replies on-link, and the router drops the rest of the
  connection. UDP DNS is unaffected, but **HTTPS to cluster-served names from
  prod-LAN DHCP clients may break**. Before rollout step 3, it is measured from
  a DHCP client on `Default`. If it breaks, those clients need the VIP route (§7
  Q2), or the conditional mapping limits prod-LAN answers to host-served names.
- **The same asymmetry in phase 2,** for the `blocky` LB address. UDP works, but
  DNS over TCP (truncated answers) from prod-LAN clients breaks. This is §7 Q2's
  gate.
- **The cluster being down** fails served names with SERVFAIL (§2.3). No worse
  than today's public path, which also crosses the cluster.
- **The API guarantee is the wrapper's.** Anyone on the LAN can
  `GET /api/blocking/disable` with no duration, and filtering then stays off
  until `on` or a restart. That is accepted under the necessity pass. The
  `BlockyFilteringOff` alert (§2.2) fires after 15 min.
- **The UniFi write.** The networks go from read-only data to managed objects. A
  partial-body `PUT` on `rest/networkconf/<id>` must merge, not replace (§7 Q4),
  and `prevent_destroy` must hold. The first `unifi-plan` is read field by
  field.
- **Query logs in Loki** are the household's browsing history, kept for Loki's
  retention. Blocky's `queryLog.fields` can drop `clientIP` and `clientName` if
  that is wanted.
- **List freshness:** up to one refresh period (4 h) plus jsDelivr's 12 h edge
  cache (§2.2). No deploy is involved.
- **Phase-2 boot ordering.** The axons resolve through their own LB first, which
  the `host`/`remote-node` ingress rule admits (§2.7). While the cluster is
  starting, they fall back to uplink, then the gateway. This is ordered by the
  list, not by luck.
- **Experimental surfaces:** none. Blocky 0.35.0 is a stable release, and every
  key used is in its configuration reference, `downloads.cachePath` included.
  `blocky validate` fails the build on a key the version doesn't know.

## 5. Alternatives rejected

- **AdGuard Home.** It writes its own YAML at runtime. With the NixOS module's
  `mutableSettings = true` (the default), UI edits drift from Nix. With `false`,
  they are lost at every restart. Either way, the config isn't one declarative
  definition that a ConfigMap can also render. Pi-hole has the same problem.
- **unbound as a recursive resolver: deferred.** Recursion sends every query in
  plaintext to the authoritative servers, which contradicts the
  encrypted-upstream ruling, and it would add a second daemon. It can later be
  an upstream of Blocky, behind the same definition.
- **Blocky on the axons as a NixOS service.** The owner keeps the axons to
  Kubernetes plus tang. Phase 2 puts it in the cluster instead, where the same
  definition renders a ConfigMap.
- **Blocklists pinned in a package** (a fixed-output fetch, v0.2): every list
  update needed a package build and a redeploy (owner ruling, §2.2). **Or as a
  flake input:** the same, and it fetched the whole repo on every bump.
- **NXDOMAIN as the block answer.** resolved's multi-link race would bypass it
  (§2.2).
- **The router as a conditional upstream** (§2.3).
- **Blocky's `customDNS` rendered from `served-domains`** instead of forwarding
  to CoreDNS. It would need no LB, and it would keep host-served names
  resolvable while the cluster is down. Not chosen, because the ruling names
  conditional forwarding (§7 Q6).
- **A tailnet subnet route to a dedicated resolver address,** for filtering off
  the LAN. It needs `--accept-routes` on Linux clients and a second address on
  uplink. Routing uplink's main LAN address over the tailnet instead would carry
  its BGP sessions and SSH too. This is a non-goal for now (§6).
- **The router as the DHCP DNS server, forwarding to Blocky.** Blocky would see
  one client (the router), so per-client logs and the fallback order would be
  lost, and the ruling names the resolver directly.

## 6. Non-goals

- Blocking clients' own DoH or DoT (browser DoH, Android Private DNS). There is
  no egress filtering of 853 or 443.
- DNSSEC validation in Blocky. The upstreams validate, as today
  (`networking.nix:82-85`).
- Serving DoT or DoH to LAN clients.
- Per-client groups, schedules or parental controls (Blocky's
  `clientGroupsBlock` beyond `default`).
- An IPv6 resolver address. Phase 1 is IPv4-only, and RDNSS is suppressed
  instead.
- Encrypting CoreDNS's own upstream, or filtering pods. CoreDNS still forwards
  `.` to `dnsServers` in plaintext.
- Filtering for tailnet clients off the LAN.
- Changing ACME's DNS-01 resolver.

## 7. Open questions

1. **The tailnet's public DoH tail.** Keep it, since without it mobile clients
   lose DNS off the LAN and whenever uplink is down, or drop it in phase 3, once
   two filtering instances make an outage unlikely? Default: keep it in phases 1
   and 2, then decide on test 1's measured leak rate.
2. **Prod-LAN to VIP asymmetry** (§4). Does a DHCP client on `Default` reach
   cluster-served names over TCP once it gets internal answers, and does it
   reach the phase-2 LB over TCP? If not, the options are a per-address route on
   clients, Cilium L2 announcements on `10.10.0.0/16`, or limiting the prod-LAN
   mapping. It is measured before rollout step 3.
3. **Phase-2 state sharing.** Blocky's Redis sync needs an in-cluster
   Redis/Valkey. The alternative is per-pod LB addresses, so the wrapper fans
   out to each pod. Default: Redis.
4. **UniFi `networkconf` semantics.** Does a partial `PUT` merge? Which fields
   carry RA RDNSS and DHCPv6 DNS, and can RDNSS be off while SLAAC stays on?
   This is read from the live object (`GET` only) during implementation.
5. **The router's own upstream.** Set the UniFi WAN DNS to Quad9 and Cloudflare
   (still plaintext, but not the ISP) so the fallback leaks less, or leave it?
6. **CoreDNS forwarding vs `customDNS`** for host-served names (§5). Forwarding
   follows the ruling and has one renderer. `customDNS` would keep
   `idm.json64.dev` resolving while the cluster is down. Default: the ruling.
7. **Phase-2 image publishing.** The Nix-built image changes on every Blocky
   bump (lists are downloaded at runtime). Push it to `registry.json64.dev`, as
   `tdarr-node` is pushed (manual `skopeo`), or to `ghcr.io/sini/blocky` from
   CI? Default: undecided, and it must be settled before phase 2.
8. **Which lists.** The default here is hagezi `pro` alone. `tif` (threat
   intelligence) is a candidate second list, and the allowlist starts empty.

## 8. Review history

**Round 1 (v0.1): 14 objections** (6 ops, 8 den-fit), all accepted.

| v0.1 objection                                              | Resolution                                                                                                                                                          |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ops 1: `tailscale0`'s `~.` means `br0` is never asked       | §1 corrected; servers and guests take `accept-dns=false` plus a `~ts.<domain>` route (§2.4b; route replaced in v0.3, owner Q13 decided); test 5 asserts `link: br0` |
| ops 2: empty allowlist renders `""`, loaded as a path       | `allowlists` omitted when empty (§2.2); VM test with control (test 9)                                                                                               |
| ops 3: `blocky validate` doesn't open lists                 | `blocky-lists` runCommand check, `test -s` on every list path (test 9); replaced in v0.3                                                                            |
| ops 4: DHCP clients may race to the unfiltered gateway      | test 13 leak count from a phone and a laptop; the gateway leaves DHCP until phase 2 if it leaks (§2.4a)                                                             |
| ops 5: Blocky can bind before `br0` has its address         | `after = network-online.target` (§2.2); reboot check (test 5)                                                                                                       |
| ops 6: phase-2 CNP lacks Redis egress                       | egress and Redis-side ingress on 6379 (§2.7); per-pod state test 14                                                                                                 |
| den-fit 1: `internalResolver` has no den path               | `dns-internal` quirk, cluster-emitted, host-collected, env-selected, as `monitoring-ingest` (§2.1, §2.3)                                                            |
| den-fit 2: cluster-emitted `dns-resolvers` never collected  | two pipes per scope, `{host}` and `{cluster}`, as `env-collect-dns` (§2.1)                                                                                          |
| den-fit 3: test 11's control fails by design                | axon-01's delta is an admission; "unchanged" kept only for the guarded collections (test 11)                                                                        |
| den-fit 4: package path wrong; `nix-update` unverified      | `pkgs/by-name/dns-blocklists/package.nix` → `pkgs.local`; local `update-pkgs` gate, `fetchurl` fallback (§2.2); package dropped in v0.3                             |
| den-fit 5: OCI updater is not nightly                       | stated as a gate in §2.10 (blocky-ui moved there)                                                                                                                   |
| den-fit 6: `allowed_groups` unprecedented; SPN groups claim | measure the claim, then gate with a check (§2.10)                                                                                                                   |
| den-fit 7: phase-1 scope cuts                               | blocky-ui, the failback timer and test 9's phase-2 check moved to §2.10                                                                                             |
| den-fit 8: "visible on the dashboard" isn't a mitigation    | `BlockyFilteringOff` alert, 15 min (§2.2, §4); fire and no-fire controls (test 6)                                                                                   |

**Round 2 (v0.2): 4 objections**, all accepted, plus two owner rulings.

| v0.2 objection or ruling                                        | Resolution                                                                                                                                                                                                                        |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1: tailscaled clobbers the `~ts.<domain>` route on `tailscale0` | oneshot deleted; `ts.<domain>` → `100.100.100.100` in both instances' `conditional.mapping` (§2.2, §2.4b, §2.7); hijack rationale kept; test 5 queries after a tailscaled restart; §4 entry rewritten                             |
| 2: `coredns-internal` under `Cluster` SNATs past the /32 rule   | `externalTrafficPolicy = "Local"`, as every repo LoadBalancer sets it (§2.3)                                                                                                                                                      |
| 3: phase-2 CNP rejects the axons' own queries                   | `fromEntities = [ "host" "remote-node" ]` on 53 and 4000 (§2.7); test 14 asserts axon-01's first server answers                                                                                                                   |
| 4: cluster `dns-resolvers` record lacks `environment`           | `environment = cluster.environment`; one form, the env name string, compared as `served-domains` is (§2.1, §2.3, §2.7)                                                                                                            |
| ruling: Q13 decided                                             | servers and microvm guests take `accept-dns=false` and the LAN resolver; roaming devices keep MagicDNS (§2.4b, §2.4c, §2.9, §4); open question 9 removed                                                                          |
| ruling: runtime blocklists replace the pinned package           | `dns-blocklists` package, its gate, fallback and image copy dropped; hagezi `pro` by URL, `refreshPeriod = "4h"`, `strategy = "fast"`, `downloads.cachePath` (§1, §2.1, §2.2, §2.7, §2.8); test 9 rewritten; §4 boot-window entry |

**Round 3 (v0.3): 8 objections** (3 den-fit, 5 ops) and 3 den-fit nits, all
accepted. Den-fit 1 and ops 1 are the same defect.

| v0.3 objection                                                                                   | Resolution                                                                                                                                                                                                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| den-fit 1 / ops 1: `network-online.target` doesn't wait for `br0`; wait-online is off fleet-wide | `after` and `wants` on `systemd-networkd-wait-online@<lan>.service`, the link from `lanLinkOf` (den data); template confirmed installed and enabled on uplink (§1, §2.2); false wait-online sentence replaced; `freeBind` doesn't cover `:4000` (§2.2); test 5's control is critical-chain listing that unit, plus an optional delayed-carrier VM control |
| den-fit 2: resolver guard keyed on `dns.resolvers`, which is `[ ]` at step 1                     | guard on the host, `isResolver` setting as `broadcast-hub-peer` keys on `isHub`; set in `uplink.nix`; aspect content gated on it (§2.1, §2.9 step 1)                                                                                                                                                                                                      |
| den-fit 3: test 9's "entries load" passes on a dead URL with a warm cache                        | test 9 empties the cache and asserts `blocky_failed_downloads_total == 0` plus a `group import finished` line; control is a 404 URL with a warm cache                                                                                                                                                                                                     |
| den-fit nit: `tailnetDomain` has no home                                                         | the `ts.${environment.domain}` expression of `headscale.nix:61`, repeated, not factored (§2.2, §2.4b)                                                                                                                                                                                                                                                     |
| den-fit nit: `StateDirectory` already exists                                                     | `cachePath = "/var/lib/blocky"`; persistence entry is `/var/lib/private/blocky`; no `CacheDirectory` (§2.2)                                                                                                                                                                                                                                               |
| den-fit nit: widen the `environment.dns` description                                             | new description given (§2.1)                                                                                                                                                                                                                                                                                                                              |
| ops 2: SERVFAIL may move clients to the unfiltered gateway                                       | test 5 records the server across a tailscaled restart on uplink and after `dnssec-failed.org`; if it moves, the failback timer joins phase 1, shape written (§2.4, §2.9, §2.10); §4 entry rewritten (SERVFAIL case, NXDOMAIN at the gateway and `1.1.1.1`, measured at tailscale 1.104.1); Blocky 0.35.0 has no key to remap a SERVFAIL                   |
| ops 3: a truncated download replaces the whole denylist                                          | two §2.2 sentences corrected; `downloads.timeout = "60s"`; `BlockyDenylistShrunk` and `BlockyDenylistEmpty` alerts (§2.2, §4); truncating-server VM control (test 9)                                                                                                                                                                                      |
| ops 4: tests 5 and 14 name `br0` on axon-01                                                      | each host's LAN link from `lanLinkOf` (`enp2s0` on axon-01), guests by MAC (tests 5, 14)                                                                                                                                                                                                                                                                  |
| ops 5: two tailnet controls don't depend on the mechanism                                        | test 5's control drops the `ts.<domain>` mapping; test 14's removes the `100.100.100.100/32` egress rule                                                                                                                                                                                                                                                  |

**Round 4 (v0.4): 7 objections** (2 den-fit, 5 ops), all accepted. The owner
then stopped the review loop.

| v0.4 objection                                                                                               | Resolution                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| den-fit 1: the failback timer's `lanLinkOf` throws on DHCP-only hosts and names the host-side tap for guests | the timer reads its link from the default route at runtime, gated on the `accept-dns=false` predicate (§2.4); `lanLinkOf` deleted, since nothing else uses it once the boot gate is gone; tests 5 and 14 name the default-route link (guests `enp0s9`, `enp0s12`, measured)                                                                                                                                                                                                                                                                     |
| den-fit 2: step 1 never sets `dns.internal` or `dns.filter`                                                  | step 1 sets both in prod.nix with `dns.resolvers = [ ]`; the §2.1 env block is split by step; the `dns-internal` selection throws with a message naming `environment.dns.internal`; dev.nix sets neither, since only a prod instance reads them (§2.1, §2.9)                                                                                                                                                                                                                                                                                    |
| ops 1: the boot gate rests on initrd timestamps                                                              | stage 2 re-measured: the address is the initrd's, kept across the switch (`flushBeforeStage2 = false`) (§1); the wait-online gate and its claims deleted, so the IPv6 stall it added is gone; `RestartSec = "2s"` plus `startLimitIntervalSec = 0` guard a boot without carrier (§2.2); the reboot check is replaced by a mandatory delayed-address VM test that must see `NRestarts ≥ 1`, with `start-limit-hit` as the control (test 5); the template unit was `disabled`, pulled in by `wants`, and the round-3 "enabled" claim is withdrawn |
| ops 2: test 9 passes on a truncated download                                                                 | test 9 also asserts the `sha256(url)` cache file and an `import succeeded` line (`download_cache.go:16-21`, `list_cache.go:376`)                                                                                                                                                                                                                                                                                                                                                                                                                |
| ops 3: test 9's 404 control can't seed                                                                       | moved to a VM test: one local URL serves 200, then 404 after a restart (test 9)                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ops 4: no alert when Blocky is dead                                                                          | `BlockyDown`, built per announced host as `HostSilent` is, on `up{job="blocky", instance=<host>}` (Alloy's labels) (§2.2); test 6's stopped-Blocky control asserts it fires                                                                                                                                                                                                                                                                                                                                                                     |
| ops 5: caches hide test 5's SERVFAIL records                                                                 | each query is preceded by `POST /api/cache/flush` and run with `resolvectl query --cache=no`; `gone.ts.json64.dev` added as the steady-state SERVFAIL record (test 5)                                                                                                                                                                                                                                                                                                                                                                           |
