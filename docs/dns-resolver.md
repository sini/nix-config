# A local filtering DNS resolver (Blocky)

Status: **draft v0.1** (2026-11-10). This is a design, not implemented and not
reviewed. It is written against `main` at `03b84230`. The owner's rulings are
fixed: Blocky through the NixOS `services.blocky` module, a `dns-filter`
wrapper, the uplink → Kubernetes → uplink-as-secondary phases, encrypted
upstreams only, four client paths, and the observability path. This document
designs within them. Where a measurement contradicts a ruling's premise, the
section says so (§1, internal names).

## 1. Problem

Nothing filters DNS today, and the fleet's resolver configuration lives in five
places that disagree. Measured on 2026-11-10 over ssh, read-only:

**Fleet hosts resolve through the tailnet, not their LAN link.** On cortex,
`tailscale0` carries `DNS Domain: ts.json64.dev ~.` with `+DefaultRoute`
(headscale `override_local_dns = true`), and `br0` carries the environment's DoT
list (`+DNSOverTLS`, `1.1.1.1#cloudflare-dns.com` …), also with `+DefaultRoute`.
systemd-resolved sends a query routed to several links to all of them, and the
first successful answer wins. `resolvectl query grafana.json64.dev` answered
from `link: tailscale0`, with "Data was acquired via local or encrypted
transport: no". So the resolver a fleet host actually uses is MagicDNS
(`100.100.100.100`), which forwards to headscale's `nameservers.global`, which
is a hard-coded Cloudflare list.

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
  roaming (`ipad`, `Open`, and `localhost` of user shuo) and leave the LAN.
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
| `environment.networks.default.unifiNetwork` | env option          | The controller network name this environment's LAN is (`"Default"`, `"dev"`)            |
| `environment.networks.default.dnsServers`   | existing env option | Unchanged, and now **Blocky's upstreams** (§2.2)                                        |
| `dns-resolvers` quirk                       | quirk               | `{ name; environment; dns; api; }` per running instance                                 |
| `services.networking.blocky`                | host aspect         | The NixOS service; emits `dns-resolvers` and `prometheus-targets`                       |
| `services.networking.blocky.ui`             | host aspect         | Optional blocky-ui (§2.6)                                                               |
| `kubernetes.services.network.blocky`        | cluster aspect      | Phase 2 Deployment; emits `dns-resolvers`                                               |
| `services/networking/blocky/_settings.nix`  | helper              | The shared definition: a function from instance inputs to Blocky's settings attrset     |
| `core/network/_resolvers.nix`               | helper              | `resolversFor environment dns-resolvers` → addresses, then `networks.default.gatewayIp` |
| `pkgs/by-name/dn/dns-blocklists`            | package             | The pinned lists (§2.2, Blocklists)                                                     |
| `services.networking.blocky.cli`            | host aspect         | `dns-filter`, built in the aspect because it needs den data (§2.5)                      |

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
  ui.enable = mkOption { type = types.bool; default = false; };
};
```

Phase 1 in the environment files:

```nix
# prod.nix and dev.nix (dev's hosts use prod's uplink; the quirk collects fleet-wide)
dns.resolvers = [ "uplink" ];
dns.filter = {
  denylists = [ "hagezi-pro" ];   # file names in dns-blocklists
  allowlist = [ ];                 # inline domains, reviewed in the diff
};
networks.default.unifiNetwork = "Default";   # dev.nix: "dev"
```

And in `hosts/uplink.nix`: `includes = [ … services.networking.blocky ];`.

**Collection.**

- `dns-resolvers` is collected fleet-wide at host scope (`collectAll`, as
  `nix-builders` is), at cluster scope (for CoreDNS's ingress policy, §2.3), and
  at environment scope for the UniFi workspace. It holds one or two records.
- The resolver host also needs the environment's `served-domains` (§2.3). Host
  scope collects none today, so a new host policy takes them, guarded the way
  `broadcast-hub-peer` is guarded. It applies only when some environment's
  `dns.resolvers` names this host, so no other host pays the collection.
  Acceptance test 11 prices it.

### 2.2 Phase 1: the service on uplink

```nix
# services/networking/blocky/_settings.nix (sketch)
{ lib }:
{ upstreams, internalNames, internalResolver, lists, filter, dnsListen, httpListen, statistics ? false }:
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
    allowlists.default = [ (lib.concatLines filter.allowlist) ];
    clientGroupsBlock.default = [ "default" ];
    blockType = "zeroIp";
    blockTTL = "1m";
    loading = { refreshPeriod = "0"; strategy = "failOnError"; };
  };
  caching.prefetching = true;
  queryLog.type = "console";
  prometheus.enable = true;
  statistics.enable = statistics;
  ports = { dns = dnsListen; http = httpListen; };
}
```

The NixOS aspect sets `services.blocky.settings` to this, with these instance
inputs:

- `dnsListen = [ "<lan>:53" ]` and
  `httpListen = [ "<lan>:4000" "127.0.0.1:4000" ]`, where `<lan>` is
  `environment.addressOn "default" host` (`10.10.10.1`).
- `internalResolver` is the cluster's `coredns-internal` address (§2.3).
- `lists = pkgs.dns-blocklists`.

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

**Block answer: `zeroIp`, not NXDOMAIN.** A fleet host races its links (§1):
`br0` goes to Blocky, and `tailscale0` goes to MagicDNS, which may race a public
DoH server (§2.4c). systemd-resolved returns the first _successful_ answer. An
NXDOMAIN from Blocky is negative, so resolved waits for the other link's
positive public answer, and the block is bypassed. `0.0.0.0` (or `::`) is a
positive answer and wins. `blockTTL = 1m`, down from the 6 h default, so that
`dns-filter off` reaches clients' caches within a minute.

**Blocklists: pinned fixed-output fetch.** Chosen over runtime download and over
a flake input.

- `pkgs/by-name/dn/dns-blocklists` is a `fetchFromGitHub` of
  `hagezi/dns-blocklists` at a release tag, `sparseCheckout`'d to the chosen
  `wildcard/*-onlydomains.txt` files. The repo is large, and the pro list alone
  is 4.4 MB. hagezi tags a release several times a day (latest
  `37522026.314.32212`, 2026-11-10).
- The nightly `update-flakes` workflow already runs `update-pkgs --no-build`,
  which bumps it. Freshness is one day plus the deploy cadence.
- Blocky's refresh is off (`refreshPeriod = "0"`). The lists are store paths, so
  a running instance never changes them.

Why:

- Reproducible: the deployed list is a reviewed hash.
- `blocky validate` checks it at build.
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
  pods on UDP and TCP 53. Cilium BGP-advertises it, and uplink, as the BGP hub,
  takes a per-address route, as it does for `10.11.0.10` through `10.11.0.31`
  today.
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
resolversFor = environment: dns-resolvers:
  if environment.dns.resolvers == [ ] then null   # null: the consumer keeps today's list
  else map (n: (lib.findFirst (r: r.name == n) (throw "dns.resolvers: no instance ${n}") dns-resolvers).dns)
         environment.dns.resolvers
       ++ [ environment.networks.default.gatewayIp ];
```

The fallback is always the environment's own gateway (prod `10.10.0.1`, dev
`10.9.0.1`, the same device), read from `gatewayIp`, which is already there. An
instance name with no running instance fails evaluation. It is not silently
dropped.

**(a) LAN DHCP: the terranix `unifi` workspace.** `unifi.nix` renders, for each
environment that sets `networks.default.unifiNetwork`, a `restapi_object` on
that `rest/networkconf/<id>`, whose fields are:

- `dhcpd_dns_enabled = true`, and `dhcpd_dns_1..n` = `resolversFor` that
  environment, at most 4;
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

**resolved does not fail back.** After failing over to the router, a link keeps
the router as its current server. A small `dns-failback.timer` (every 5 min) on
hosts with resolvers set checks the link's current server. If the server isn't
the first resolver and the first one answers a probe, the timer re-applies the
link's list (`resolvectl dns <link> …`), which resets the current server to the
first. Test 5 measures the need first. If resolved already fails back, the timer
is dropped.

**(c) headscale.** `nameservers.global` = `resolversFor` without the gateway,
followed by the environment's `dnsServers` addresses (with `#name` stripped,
which tailscaled upgrades to DoH). The router is excluded: it is a private
address, so tailscaled would race it at once, and it is unreachable off the LAN
anyway. The public tail is there for the roaming nodes (§1). Without it, an
`ipad` off the LAN, or any tailnet-only client while uplink is down, has no DNS
at all, which is a regression from today. With it, tailscaled races Blocky
against DoH:

- On the LAN, Blocky's local answers (blocked names, internal names, cache hits)
  arrive in about a millisecond, against at least one DoH round trip. Blocky
  usually wins, but nothing guarantees it.
- Off the LAN, answers are unfiltered but encrypted, as today.

Test 1 counts the leak rate on the tailnet path. §7 Q1 asks whether to drop the
tail in phase 3, when two filtering instances exist.

**(d) Fallback.** This is the gateway, appended by `resolversFor` for paths (a)
and (b). It is excluded from (c), for the reasons given there.

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

### 2.6 blocky-ui (optional)

- **Not in nixpkgs** (checked at `600291ca`). The upstream image
  `ghcr.io/gabeduartem/blocky-ui` is pinnable. Tags run from `2.0.0` to `2.2.0`,
  and `2.2.0` is
  `sha256:9cf986ea7b1e9b01d082a0eec5cb93a4322bbadff3a411633c10ed668eb01528`. It
  is pinned as `images/gabeduartem/blocky-ui/default.nix`, which the OCI updater
  tracks. It is MIT-licensed, listens on 3000, and is configured by
  `BLOCKY_UI_CONFIG`. It has no built-in authentication.
- **How it runs:** with `services.networking.blocky.settings.ui.enable`, a
  podman `oci-containers` unit runs on uplink (which already includes
  `virtualization.podman`), on `127.0.0.1:3000`. Its config is rendered from the
  `dns-resolvers` records, one `servers.<name>.url` per instance. It has no
  `logSources`, because a `console` query log isn't readable to it without
  VictoriaLogs. It uses Blocky's rolling 24 h statistics instead
  (`statistics.enable`, set only when the UI is on).
- **Behind Kanidm** it follows the `homepage.nix` pattern: an
  `environment.services.blocky-ui.domain` (prod `dns.json64.dev`), an nginx
  vhost proxying to `127.0.0.1:3000` with `useACMEHost`, and
  `services.oauth2-proxy.nginx.virtualHosts.<domain>` with `allowed_groups` set
  to the Kanidm admins group, through the existing `oauth2-proxy` Kanidm client.
  It also emits `served-domains`. The UI can disable filtering, so it is
  admin-gated.

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
  `pkgs.dns-blocklists`), so the pod runs the same binary and lists as phase
  1. The lists can't go in the ConfigMap: the pro list alone is 4.4 MB, against
     a 1 MiB limit.
- **Deployment:** 3 replicas, one per node (pod anti-affinity).
- **Service:** `LoadBalancer` on a new `blocky` assignment in
  `kubernetes-loadbalancers`, UDP/TCP 53 and TCP 4000, with
  `externalTrafficPolicy: Local`, so client addresses reach the query log and
  only nodes with an endpoint advertise.
- **CiliumNetworkPolicies:** ingress from `world` on 53, and from the `blocky`
  LB clients on 4000; egress to `world` on TCP 853 only; and Prometheus on 4000.
- **The `dns-resolvers` record:**
  `{ name = "axon"; dns = <blocky LB>; api = "http://<blocky LB>:4000"; }`.
- **Replica state:** `dns-filter` reaches one replica through the LB, so the
  replicas share blocking state through Blocky's `redis` option. Blocky
  documents that it "can synchronize its cache and blocking state between
  multiple instances". This needs a small in-cluster Redis or Valkey (§7 Q3).
  uplink stays a separate instance, and the wrapper fans out to both.
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

1. `dns-blocklists`, `_settings.nix`, and the `services.networking.blocky`
   aspect, with uplink including it, and the `coredns-internal` LB and policy.
   No client changes yet, since `dns.resolvers = [ ]`. Tests 1–3, 6, 8 and 9 run
   against `@10.10.10.1` directly.
2. `dns.resolvers = [ "uplink" ]` in both environments, plus the (b) and (c)
   consumers and the D10 cleanup. Tests 5, 7 and 11.
3. The UniFi DHCP and RA change (`unifi-plan`, reviewed, then `unifi-apply`).
   Tests 5 (DHCP client) and 10.
4. Optionally, blocky-ui.
5. Phase 2 starts once tests 1–11 hold for a week, with §7 Q2 and Q3 answered.

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
   - Tailnet path: on cortex, resolve 1000 list domains through
     `resolvectl query`, and count the answers that aren't `0.0.0.0`. Record the
     leak rate (§2.4c). The same run with `dns.resolvers = [ ]` must leak 1000
     of 1000.
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
5. **The fallback while the resolver is down.**
   - Stop `blocky.service` on uplink. Then `resolvectl query example.com`
     succeeds on cortex, uplink-dev, cortex-cuda and axon-01, and on a LAN DHCP
     client after step 3. Repeat with uplink powered off, which also removes
     headscale.
   - Control: on cortex, with the link temporarily set to
     `resolvectl dns br0 10.10.10.1` (no fallback) and tailscale down, the query
     fails, so the earlier success came through the fallback.
   - Failback: start blocky again. Within 10 min, `resolvectl status` on each
     static host shows the first resolver as the current server. Control: with
     `dns-failback.timer` masked, record whether it stays on the gateway. If it
     fails back without the timer, the timer is dropped (§2.4b).
6. **Metrics and logs arrive.**
   - In Prometheus, `up{job="blocky", instance="uplink"} == 1`, and
     `blocky_blocking_enabled` is present.
   - In Loki, `{unit="blocky.service"} |= "<uuid>.example.com"` returns the
     query within 2 min of resolving it.
   - The dashboard's panels are non-empty.
   - Controls: a second, never-queried uuid returns 0 lines. With
     `blocky.service` stopped, `up` goes to 0 within two scrape intervals.
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
9. **Build-time checks.**
   - `blocky validate` runs in `system.checks`. Control: a denylist path to a
     missing file fails the build.
   - Phase 2: a check renders `_settings.nix` for both aspects and asserts the
     two YAMLs are equal outside `ports`, `conditional.mapping` values, the list
     directory and `redis`. Control: changing one side's `blockType` fails the
     check.
10. **No RDNSS bypass.** After step 3, a LAN phone's and laptop's DNS list holds
    only `resolversFor` and the gateway, with no `2001:5a8:…::1`. Control:
    before step 3, the same device lists the router's IPv6 address.
11. **Evaluation cost.** Measure uplink's and axon-01's evaluation time and peak
    memory before and after rollout steps 1 and 2 (capped at 12G, same machine,
    three runs). Only uplink may move, and only by the served-domains
    collection. Control: axon-01's cost is unchanged within run-to-run noise.
12. **Cross-environment reach.** `dig @10.10.10.1 example.com` from cortex (dev
    LAN, through the router) answers. Control: with port 53 closed in uplink's
    firewall, it times out.

## 4. Risks

- **A plaintext LAN hop.** Today, a host's `br0` link speaks strict DoT to
  Cloudflare. After the change it speaks plain DNS to Blocky, and Blocky speaks
  DoT out. The ISP sees nothing either way, but a LAN attacker sees host
  queries. Accepted under the owner's necessity pass. Serving DoT on the LAN is
  a non-goal (§6).
- **The tailnet race (§2.4c).** Filtering on the tailnet path is best-effort
  while the public DoH tail stays. Test 1 measures it.
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
  `blocky_blocking_enabled == 0` series makes it visible on the dashboard.
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
