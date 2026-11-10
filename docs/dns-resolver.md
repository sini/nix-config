# A local filtering DNS resolver (Blocky)

Status: **draft v0.2** (2026-11-10), revised against review round 1 (§8). This
is a design, not implemented. It is written against `main` at `03b84230`. The
owner's rulings are fixed: Blocky through the NixOS `services.blocky` module, a
`dns-filter` wrapper, the uplink → Kubernetes → uplink-as-secondary phases,
encrypted upstreams only, four client paths, and the observability path. This
document designs within them. Where a measurement contradicts a ruling's
premise, the section says so (§1, internal names).

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
`enp0s8: 1.1.1.1 8.8.8.8 2001:5a8:608c:b600::1` with `-DNSOverTLS`, so the guest
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
  `net.ipv4.ip_nonlocal_bind = 0`.
- tailscaled races every global nameserver (`net/dns/resolver/forwarder.go`,
  `forwardWithDestChan`), and the first success wins. A private address starts
  at once. A well-known public IP is upgraded to DoH, which also starts at once,
  and its plain-UDP leg is delayed by 500 ms.
- The pinned nixpkgs (`nixpkgs-master` `600291ca`, uplink's channel) ships
  `blocky` 0.35.0. Its module renders `settings` with `pkgs.formats.yaml` and
  runs `blocky validate` at build time (`enableConfigCheck`, default on).
  `blocky-ui` is not packaged.

## 2. Design

One shared Nix definition renders Blocky's YAML. A NixOS aspect and a Kubernetes
aspect both feed it, and each supplies only listen addresses, the CoreDNS
address and the list directory. An environment names its resolver instances.
Every client path (DHCP, static hosts and guests, headscale) reads that one
setting through one helper.

### 2.1 Den shape

| Piece                                       | Kind                | Holds                                                                                   |
| ------------------------------------------- | ------------------- | --------------------------------------------------------------------------------------- |
| `environment.dns.resolvers`                 | env option          | Ordered instance names (host or cluster). `[ ]` = today's behaviour                     |
| `environment.dns.filter`                    | env option          | `denylists`, `allowlist` (list names and inline domains): the same for every instance   |
| `environment.dns.internal`                  | env option          | Cluster whose `dns-internal` record is the conditional upstream (`"axon"`), or `null`   |
| `dns-internal` quirk                        | quirk               | `{ cluster; address; }`, emitted by the CoreDNS cluster aspect (§2.3)                   |
| `environment.networks.default.unifiNetwork` | env option          | The controller network name this environment's LAN is (`"Default"`, `"dev"`)            |
| `environment.networks.default.dnsServers`   | existing env option | Unchanged, and now **Blocky's upstreams** (§2.2)                                        |
| `dns-resolvers` quirk                       | quirk               | `{ name; environment; dns; api; }` per running instance                                 |
| `services.networking.blocky`                | host aspect         | The NixOS service; emits `dns-resolvers` and `prometheus-targets`                       |
| `kubernetes.services.network.blocky`        | cluster aspect      | Phase 2 Deployment; emits `dns-resolvers`                                               |
| `services/networking/blocky/_settings.nix`  | helper              | The shared definition: a function from instance inputs to Blocky's settings attrset     |
| `core/network/_resolvers.nix`               | helper              | `resolversFor environment dns-resolvers` → addresses, then `networks.default.gatewayIp` |
| `pkgs/by-name/dns-blocklists/package.nix`   | package             | `pkgs.local.dns-blocklists`, the pinned lists (§2.2, Blocklists)                        |
| `services.networking.blocky.cli`            | host aspect         | `dns-filter`, built in the aspect because it needs den data (§2.5)                      |
| `core.network.tailscale`                    | existing aspect     | `--accept-dns=false` plus a `~ts.<domain>` route on `tailscale0` (§2.4b)                |

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
};
```

Phase 1 in the environment files:

```nix
# prod.nix and dev.nix (dev's hosts use prod's uplink; the quirk collects fleet-wide)
dns.resolvers = [ "uplink" ];
dns.internal = "axon";
dns.filter = {
  denylists = [ "hagezi-pro" ];   # file names in dns-blocklists
  allowlist = [ ];                 # inline domains, reviewed in the diff
};
networks.default.unifiNetwork = "Default";   # dev.nix: "dev"
```

And in `hosts/uplink.nix`: `includes = [ … services.networking.blocky ];`.

**Collection.**

- `dns-resolvers` is emitted by a host (phase 1) and by a cluster (phase 2). A
  `collectAll` predicate matches only the entity kind it names, so every
  collecting scope declares two pipes, `({ host, ... }: true)` and
  `({ cluster, ... }: true)`, as `env-collect-dns` does for `served-domains`
  (`policies/pipes.nix:232-235`). The scopes are host (clients and
  `dns-filter`), cluster (CoreDNS's ingress policy, §2.3) and environment (the
  UniFi workspace). It holds one or two records.
- `dns-internal` copies `monitoring-ingest`: the cluster emits it, a host policy
  `collect-dns-internal` collects it with `collectAll ({ cluster, ... }: true)`
  (as `pipes.nix:194-199` does), and the resolver host selects it with
  `lib.findFirst (i: i.cluster == environment.dns.internal) null dns-internal`
  (as `alloy.nix:20-21` does). The policy carries the resolver-host guard below,
  so only a resolver host collects it.
- The resolver host also needs the environment's `served-domains` (§2.3). Host
  scope collects none today, so a new host policy takes them, guarded the way
  `broadcast-hub-peer` is guarded. It applies only when some environment's
  `dns.resolvers` names this host, so no other host pays the collection.
- Every host does pay for `dns-resolvers` (two pipes, one or two records),
  `resolversFor` in `networking.nix`, and `dns-filter` from `roles.default`.
  That is a fleet-wide eval delta, admitted and priced on axon-01 by test 11.

### 2.2 Phase 1: the service on uplink

```nix
# services/networking/blocky/_settings.nix (sketch)
{ lib }:
{ upstreams, internalNames, internalResolver, lists, filter, dnsListen, httpListen }:
{
  upstreams = {
    strategy = "parallel_best";
    init.strategy = "fast";
    groups.default = map toBlockyUpstream upstreams;   # "1.1.1.1#cloudflare-dns.com" -> "tcp-tls:1.1.1.1:853#cloudflare-dns.com"
  };
  bootstrapDns = [ (toBlockyUpstream (lib.head upstreams)) ];
  conditional.mapping = lib.genAttrs internalNames (_: internalResolver);
  blocking = {
    denylists.default = map (n: "${lists}/${n}.txt") filter.denylists;
    # an empty inline list renders "" and loads as a file path; omit the key
  } // lib.optionalAttrs (filter.allowlist != [ ]) {
    allowlists.default = [ (lib.concatLines filter.allowlist) ];
  } // {
    clientGroupsBlock.default = [ "default" ];
    blockType = "zeroIp";
    blockTTL = "1m";
    loading = { refreshPeriod = "0"; strategy = "failOnError"; };
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
- `lists = pkgs.local.dns-blocklists`.
- `systemd.services.blocky.after = [ "network-online.target" ]`. The module only
  `wants` it (§1), so on boot Blocky can try to bind `10.10.10.1` before `br0`
  has it and fail with `EADDRNOTAVAIL`. networkd's wait-online covers `br0`
  (`requiredForOnline` defaults to `routable`, `networking.nix`).
  `ip_nonlocal_bind` would also work, but it is a host-wide sysctl and lets
  Blocky run on an address the host doesn't hold. Test 5 checks a reboot.

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
back to the OS resolver, and on uplink that is Blocky itself.

**Block answer: `zeroIp`, not NXDOMAIN.** After §2.4b, a fleet server has one
DNS path, so no link race remains there. The race that remains is on the tailnet
path for roaming devices: tailscaled races Blocky against a public DoH server
(§2.4c). An NXDOMAIN is a negative answer that a racer can discard in favour of
the other's positive public answer. `0.0.0.0` (or `::`) is a positive answer, so
it holds whichever rule the racer applies. `blockTTL = 1m`, down from the 6 h
default, so that `dns-filter off` reaches clients' caches within a minute.

**Blocklists: pinned fixed-output fetch.** Chosen over runtime download and over
a flake input.

- `pkgs/by-name/dns-blocklists/package.nix` (`pkgs.local.dns-blocklists`) is a
  `fetchFromGitHub` of `hagezi/dns-blocklists` at a release tag,
  `sparseCheckout`'d to the chosen `wildcard/*-onlydomains.txt` files. The repo
  is large, and the pro list alone is 4.4 MB. hagezi tags a release several
  times a day (latest `37522026.314.32212`, 2026-11-10).
- The nightly `update-flakes` workflow already runs `update-pkgs --no-build`
  (`.github/workflows/update-flakes.yml:30`), which bumps it. Freshness is one
  day plus the deploy cadence. That `nix-update` handles a `sparseCheckout`
  source and hagezi's tag format is **unverified**: rollout step 1 runs
  `update-pkgs dns-blocklists` locally first. If it fails, the package is one
  `fetchurl` per list file at the tag, with a `passthru.updateScript`.
- Blocky's refresh is off (`refreshPeriod = "0"`). The lists are store paths, so
  a running instance never changes them.

Why:

- Reproducible: the deployed list is a reviewed hash.
- A build check opens it (test 9); `blocky validate` does not open lists.
- Two instances on the same commit filter identically, which matters in phase 3.
- There is no runtime dependency on GitHub, and no window where a fresh start
  serves empty lists. `failOnError` is safe, because a store path can't go
  missing: a load failure is a defect, and the fleet's failed-unit alert reports
  it.

The cost is a deploy per list bump, which the nightly PR already batches with
flake updates. Runtime download would be fresher (Blocky refreshes every 4 h),
but it is unreviewed, varies between instances, and starts unfiltered when
GitHub is unreachable. A flake input would fetch the whole repo on every bump.

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

**Alert.** One rule in `kubernetes/services/monitoring/prometheus.nix`, beside
`HostSilent` in `additionalPrometheusRulesMap.hosts`:
`alert = "BlockyFilteringOff"`, `expr = "blocky_blocking_enabled == 0"`,
`for = "15m"`, `severity = "warning"`. A disable longer than the wrapper's
default, or an indefinite one through the raw API, pages. Its series arrives by
the same path as test 6's metrics.

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
  pods on UDP and TCP 53, and emits the `dns-internal` record
  `{ cluster = cluster.name; address = cluster.getAssignment "coredns-internal"; }`,
  as `ingest.nix:24-31` emits `monitoring-ingest`. Cilium BGP-advertises it, and
  uplink, as the BGP hub, takes a per-address route, as it does for `10.11.0.10`
  through `10.11.0.31` today.
- `allow-kube-dns-cluster-ingress` gains a `fromCIDR` rule. Its addresses are
  the `dns-resolvers` records' addresses in the cluster's environment, as /32s:
  only the resolver instances may query CoreDNS from outside the cluster.

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

- **They leave MagicDNS** (pending owner Q13, §7). Today `tailscale0` carries
  `~.`, so resolved never asks `br0` (§1), and nothing below would take effect.
  `core.network.tailscale` adds `--accept-dns=false` to `extraSetFlags` on every
  NixOS host whose `resolversFor` is non-null and that does not include
  `core.network.manager`. It uses `extraSetFlags`, not `extraUpFlags`, for the
  reason `services/k3s/node.nix:143-147` gives: `up` runs only on first auth.
  The axons already do this (§1).
- **MagicDNS names keep one route.** A oneshot `tailscale-dns-route.service`
  runs `resolvectl dns tailscale0 100.100.100.100`,
  `resolvectl domain tailscale0 '~ts.<domain>'` and
  `resolvectl default-route tailscale0 false`. `<domain>` comes from the same
  `ts.${environment.domain}` expression as `headscale.nix:61`, factored into one
  helper that both read. The unit `BindsTo` the `tailscale0` device and is
  `PartOf` `tailscaled.service`, so it re-applies when the device returns. A
  route-only `~` domain is not a search domain, so it doesn't reach
  `resolv.conf`'s `search` line, which was the axons' reason for
  `accept-dns=false` (`node.nix:148-155`). The axons get the unit too.
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
failover. Phase 1 builds nothing for it. Test 5 records the current server after
Blocky returns. A failback timer is a later-phase item (§2.10), built only if
that record shows the link staying on the gateway.

**(c) headscale, for roaming devices.** After (b), only roaming devices use
MagicDNS: the three mobile nodes, `blade`, and the darwin hosts
(`tailscale/darwin.nix:67` keeps `--accept-dns=true`). Off-LAN filtering is
best-effort (pending owner Q13). `nameservers.global` =
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
- `lists` = the same `dns-blocklists` store path, shipped inside the image (see
  below).

The rest:

- **Config:** `pkgs.formats.yaml` output in a ConfigMap. Its checksum is a pod
  annotation, so a list or config change rolls the pods.
- **Image:** Nix-built (`dockerTools.streamLayeredImage` of `pkgs.blocky` plus
  `pkgs.local.dns-blocklists`), so the pod runs the same binary and lists as
  phase
  1. The lists can't go in the ConfigMap: the pro list alone is 4.4 MB, against
     a 1 MiB limit.
- **Deployment:** 3 replicas, one per node (pod anti-affinity).
- **Service:** `LoadBalancer` on a new `blocky` assignment in
  `kubernetes-loadbalancers`, UDP/TCP 53 and TCP 4000, with
  `externalTrafficPolicy: Local`, so client addresses reach the query log and
  only nodes with an endpoint advertise.
- **CiliumNetworkPolicies:** ingress from `world` on 53, and from the `blocky`
  LB clients on 4000; egress to `world` on TCP 853 only; and Prometheus on 4000.
  Egress from the blocky pods to the Redis pod on TCP 6379, and on the Redis
  side ingress on 6379 from the blocky pods only. Without that egress rule the
  replicas start, serve, and silently keep separate blocking state.
- **The `dns-resolvers` record:**
  `{ name = "axon"; dns = <blocky LB>; api = "http://<blocky LB>:4000"; }`.
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
definition and one list hash at one commit, so they answer identically. That is
what makes racing them (tailnet) or failing over between them (resolved, DHCP)
safe. The gateway stays the last resort.

### 2.9 Rollout

1. `dns-blocklists` (after `update-pkgs dns-blocklists` works locally),
   `_settings.nix`, the `services.networking.blocky` aspect with uplink
   including it, the alert, and the `coredns-internal` LB, `dns-internal` record
   and policy. No client changes yet, since `dns.resolvers = [ ]`. Tests 1–3, 6,
   8 and 9 run against `@10.10.10.1` directly.
2. `dns.resolvers = [ "uplink" ]` in both environments, plus the (b) and (c)
   consumers (including `accept-dns=false` and the `~ts.<domain>` route) and the
   D10 cleanup. Tests 5, 7 and 11. Owner Q13 must be answered first.
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
- **A failback timer.** Only if test 5's record shows a link staying on the
  gateway after Blocky returns.
- **Test 9's phase-2 render equality.** Lands with phase 2, when the second
  renderer exists.

Each step is reversible by reverting its commit. `dns.resolvers = [ ]` restores
today's client lists exactly.

## 3. Acceptance

Each test has a control that must FAIL without the mechanism. A control that
passes means the test proves nothing.

1. **Blocking.** `dig @10.10.10.1 A <d>` and `AAAA <d>`, for a domain `<d>`
   taken from the pinned list file, answer `0.0.0.0` and `::` with TTL ≤ 60.
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
5. **One path, and the fallback while the resolver is down.**
   - With Blocky up, `resolvectl query example.com` on cortex, uplink-dev,
     cortex-cuda and axon-01 answers `-- link: br0` (the guests' LAN link name
     on the guests), and `resolvectl query uplink.ts.json64.dev` answers
     `100.72.240.66` from `link: tailscale0`. Control: at `03b84230`, cortex
     answers from `link: tailscale0` (40 of 40, §1), and axon-01 answers
     NXDOMAIN for the tailnet name.
   - Stop `blocky.service` on uplink. Then `resolvectl query example.com`
     succeeds on the same hosts, still from the LAN link, and on a LAN DHCP
     client after step 3 if test 13 kept the gateway. Repeat with uplink powered
     off, which also removes headscale.
   - Control: on cortex, with the link temporarily set to
     `resolvectl dns br0 10.10.10.1` (no fallback), the query fails, so the
     earlier success came through the fallback and not through `tailscale0`.
   - Failback: start Blocky again and record each host's current server after 10
     min. This is a record, not a gate. It decides the later-phase failback
     timer (§2.10).
   - Boot: reboot uplink. `dig @10.10.10.1 example.com` from cortex answers
     within 2 min of uplink's `multi-user.target`,
     `systemctl show blocky -p NRestarts` is `0`, and
     `systemd-analyze critical-chain blocky.service` lists
     `network-online.target`. Control: the same `critical-chain` on the current
     module (no `after`) does not list it.
6. **Metrics and logs arrive.**
   - In Prometheus, `up{job="blocky", instance="uplink"} == 1`, and
     `blocky_blocking_enabled` is present.
   - In Loki, `{unit="blocky.service"} |= "<uuid>.example.com"` returns the
     query within 2 min of resolving it.
   - The dashboard's panels are non-empty.
   - Controls: a second, never-queried uuid returns 0 lines. With
     `blocky.service` stopped, `up` goes to 0 within two scrape intervals.
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
9. **Build-time checks.** `blocky validate` runs in `system.checks`, but it does
   not open lists, so it can't catch a bad list path. A second check,
   `checks.<system>.blocky-lists`, is a `runCommand` over the rendered settings:
   every `denylists` and `allowlists` entry that is not inline (has no newline)
   must be an existing, non-empty file (`test -s`).
   - Control: a denylist naming a file absent from `dns-blocklists` fails
     `blocky-lists`, while `blocky validate` alone passes it.
   - Empty allowlist: with `allowlist = [ ]`, the rendered YAML has no
     `allowlists` key, and a NixOS VM test starts `blocky.service` and resolves
     `example.com`. Control: forcing `allowlists.default = [ "" ]` makes the
     same VM test's unit fail (`failOnError`).
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
14. **Phase 2: shared blocking state.** `dns-filter off 5m` through the LB, then
    `GET /api/blocking/status` on each pod IP from a node: every pod reports
    `enabled=false`. Control: with the Redis egress rule removed, only the pod
    the LB picked reports `enabled=false`.

## 4. Risks

- **A plaintext LAN hop.** Today, a host's `br0` link speaks strict DoT to
  Cloudflare. After the change it speaks plain DNS to Blocky, and Blocky speaks
  DoT out. The ISP sees nothing either way, but a LAN attacker sees host
  queries. Accepted under the owner's necessity pass. Serving DoT on the LAN is
  a non-goal (§6).
- **The tailnet race (§2.4c).** Filtering on the tailnet path is best-effort
  while the public DoH tail stays. After §2.4b only roaming devices take that
  path. Test 1 measures it.
- **Servers leave MagicDNS (pending Q13).** A server resolves tailnet names only
  through the `~ts.<domain>` route. If `tailscale-dns-route.service` fails,
  those names fall to `br0`, where the public `*.ts.json64.dev` wildcard answers
  with Cloudflare (`node.nix:151`). Test 5 checks the route.
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
- **A one-day list lag** plus the deploy cadence (§2.2).
- **Phase-2 boot ordering.** The axons resolve through their own LB first. While
  the cluster is starting, they fall back to uplink, then the gateway. This is
  ordered by the list, not by luck.
- **Experimental surfaces:** none. Blocky 0.35.0 is a stable release, and every
  key used is in its configuration reference. `blocky validate` fails the build
  on a key the version doesn't know.

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
- **Blocklists downloaded at runtime, or as a flake input** (§2.2).
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
7. **Phase-2 image publishing.** The Nix-built image changes on every list bump.
   Push it to `registry.json64.dev`, as `tdarr-node` is pushed (manual
   `skopeo`), or to `ghcr.io/sini/blocky` from CI? Default: undecided, and it
   must be settled before phase 2.
8. **Which lists.** The default here is hagezi `pro` alone. `tif` (threat
   intelligence) is a candidate second list, and the allowlist starts empty.
9. **Do fleet servers and guests leave MagicDNS? Pending owner Q13.** The design
   assumes yes (§2.4b): `--accept-dns=false` on non-roaming NixOS hosts, with
   only `ts.<domain>` routed to quad-100, and roaming devices keeping MagicDNS
   with best-effort filtering off the LAN (§2.4c). If the owner rules no, the
   only arm that filters fleet servers is `Domains=~.` on the LAN link, which
   races both links and leaks at test 1's measured rate.

## 8. Review history

**Round 1 (v0.1): 14 objections** (6 ops, 8 den-fit), all accepted.

| v0.1 objection                                              | Resolution                                                                                                                                     |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| ops 1: `tailscale0`'s `~.` means `br0` is never asked       | §1 corrected; servers and guests take `accept-dns=false` plus a `~ts.<domain>` route (§2.4b, Q9 pending owner Q13); test 5 asserts `link: br0` |
| ops 2: empty allowlist renders `""`, loaded as a path       | `allowlists` omitted when empty (§2.2); VM test with control (test 9)                                                                          |
| ops 3: `blocky validate` doesn't open lists                 | `blocky-lists` runCommand check, `test -s` on every list path (test 9)                                                                         |
| ops 4: DHCP clients may race to the unfiltered gateway      | test 13 leak count from a phone and a laptop; the gateway leaves DHCP until phase 2 if it leaks (§2.4a)                                        |
| ops 5: Blocky can bind before `br0` has its address         | `after = network-online.target` (§2.2); reboot check (test 5)                                                                                  |
| ops 6: phase-2 CNP lacks Redis egress                       | egress and Redis-side ingress on 6379 (§2.7); per-pod state test 14                                                                            |
| den-fit 1: `internalResolver` has no den path               | `dns-internal` quirk, cluster-emitted, host-collected, env-selected, as `monitoring-ingest` (§2.1, §2.3)                                       |
| den-fit 2: cluster-emitted `dns-resolvers` never collected  | two pipes per scope, `{host}` and `{cluster}`, as `env-collect-dns` (§2.1)                                                                     |
| den-fit 3: test 11's control fails by design                | axon-01's delta is an admission; "unchanged" kept only for the guarded collections (test 11)                                                   |
| den-fit 4: package path wrong; `nix-update` unverified      | `pkgs/by-name/dns-blocklists/package.nix` → `pkgs.local`; local `update-pkgs` gate, `fetchurl` fallback (§2.2)                                 |
| den-fit 5: OCI updater is not nightly                       | stated as a gate in §2.10 (blocky-ui moved there)                                                                                              |
| den-fit 6: `allowed_groups` unprecedented; SPN groups claim | measure the claim, then gate with a check (§2.10)                                                                                              |
| den-fit 7: phase-1 scope cuts                               | blocky-ui, the failback timer and test 9's phase-2 check moved to §2.10                                                                        |
| den-fit 8: "visible on the dashboard" isn't a mitigation    | `BlockyFilteringOff` alert, 15 min (§2.2, §4); fire and no-fire controls (test 6)                                                              |
