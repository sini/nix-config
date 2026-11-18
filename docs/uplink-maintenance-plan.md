# Uplink extended maintenance: removing it as a single point of failure

Status: draft for the owner's review (2026-11-16). Nothing here is implemented.

## Goal

Take uplink down for several days next week without losing logins, the tailnet,
DNS, the cluster's reachability, or CI. Each service on uplink either moves into
the axon cluster, gets a second instance, or is explicitly accepted as down for
the window.

## What runs on uplink today (measured 2026-11-16)

uplink: 32 cores, 125 GiB RAM, one 4 TB NVMe (ZFS). Running services by memory,
and what depends on them:

| Service                                               | Mem    | State  | Who depends on it                                                                                                     |
| ----------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------------------------------------------------------- |
| kanidm (+ gateway-upstream nginx, kanidm-mail-sender) | 80 MB  | 0.9 MB | every OIDC login; xmsg-gateway's AS/introspection (`kanidmHost = "uplink"` in clusters/axon.nix)                      |
| headscale (+ embedded DERP, STUN)                     | 52 MB  | 0.3 MB | the whole tailnet: control plane, MagicDNS, DERP relay for roaming peers                                              |
| blocky (DNS)                                          | 130 MB | —      | prod: one of two resolvers (axon + uplink); **dev env and roaming: uplink only**                                      |
| frr (BGP hub, AS 65000)                               | 44 MB  | —      | axons' default route from the hub. The axons also peer with the UDM directly (verified), so cluster LB routes survive |
| atticd (CI binary cache)                              | 466 MB | 25 GB  | substituter on every host (`fallback = true`); CI publish steps                                                       |
| docker-registry                                       | 18 MB  | 2 GB   | registry.json64.dev consumers (to enumerate)                                                                          |
| nix-serve + roles.nix-builder                         | 31 MB  | —      | remote builds (bitstream is the other builder, 2 jobs)                                                                |
| alertmanager (host alerts → SMTP)                     | 36 MB  | —      | host-level alert mail                                                                                                 |
| jellyfin                                              | 54 GB* | 99 GB  | media playback. Library is on the NAS (10.10.10.10:/volume2/data, NFS)                                                |
| open-webui, ollama                                    | 0.9 GB | —      | chat UI (inference has moved to cortex-cuda)                                                                          |
| homepage, oauth2-proxy, den-docs-mirror, gen-status   | small  | —      | dashboards and static pages                                                                                           |
| microvm@uplink-dev                                    | 16 GB  | 20 GB  | den-ag-design agent sessions; an xmsg node (sini.uplink-dev)                                                          |
| syncthing, alloy, exporters                           | small  | —      | sync peer, log and metric shipping                                                                                    |

\* jellyfin's cgroup memory includes page cache; its working set is far smaller.

Capacity elsewhere: axon-01/02/03 run at 3–10% CPU and 27–38% memory
(`kubectl top`). bitstream has 12 cores, 29 GiB RAM and a load of 5–7 (genie
tiers), so it's the weaker candidate.

## Plan by tier

### Tier 0: the fleet breaks without these. Must be done before the window.

1. **kanidm: replicated NixOS services on the axon hosts (owner, 2026-11-17).**
   - Not a pod. The server runs on the hosts, and envoy proxies `idm.json64.dev`
     to every replica, as it already proxies uplink's instance today. So the
     cluster is in identity's path either way. What replication buys is a real
     multi-writer failover, not one pod rescheduling.
   - It keeps provisioning as it is: the NixOS module
     (`services.kanidm.provision` plus our extra JSON) runs on one designated
     node, and replication carries it to the others. That avoids re-homing
     provisioning in terranix or a job.
   - Migration without a cut-over:
     1. Add the axon replicas, replicating from uplink.
     2. Let them catch up, then add them to envoy's backends.
     3. Retire uplink's instance.
   - headscale depends on it: its OIDC block sets
     `only_start_if_oidc_is_available`, so kanidm must be reachable before
     headscale starts. Replicas make that much less fragile.
   - SSH doesn't depend on it: users keep static authorized keys, and opkssh
     also accepts Google as an issuer.
   - Scoped (2026-11-17). Upstream facts are from the kanidm book's replication
     chapters; repo facts are from `services/security/kanidm.nix`,
     `gateway/host-upstreams.nix` and `xmsg-gateway.nix`.
     - **Replication config.** nixpkgs' `services.kanidm.server.settings` is
       freeform, so `[replication]` needs no module work. Each node sets
       `origin = "repl://<host address>:8445"` and a bind address, plus one
       `[replication."repl://<partner>:8445"]` table per partner with
       `type = "mutual-pull"` and `partner_cert`. Port 8444 is taken on uplink
       by nginx's PROXY listener. The firewall opens the replication port to the
       partner addresses only.
     - **Certificates.** Each node generates its own replication identity
       certificate the first time it starts with `[replication]` set. Read it
       with `kanidmd show-replication-certificate`. It's a public certificate,
       so it's committed in plain text with no agenix (owner, 2026-11-17), as
       `.secrets/hosts/<host>/kanidm-replication.crt`, beside the host's other
       public material (`syncthing-uplink.crt`, `xmsg-sini-fed-ca.crt`), never
       next to the aspect. Bootstrapping takes two deploys per node: first with
       `[replication]` and no partners, then with the certificates committed.
       Certificates expire after 4 years
       (`kanidmd renew-replication-certificate`, then recommit). A check should
       assert that every partner's certificate is present and not near expiry.
     - **Joining.** uplink is the primary and must NOT set `automatic_refresh`.
       Each axon sets `automatic_refresh = true` toward uplink only, so its
       first start replaces its database with uplink's. When content conflicts,
       the primary wins. The axons pair with each other in full mesh, without
       `automatic_refresh`. After uplink retires, the writer (below) is the
       refresh source for any new node.
     - **Writer: axon-01 (owner, 2026-11-17).** It runs everything that writes
       on its own: the `services.kanidm.provision` run, the `entryManagement`
       migrations (they assert fixed UUIDs, and running them on two nodes before
       those nodes sync risks replication conflicts), the mail-sender bootstrap
       and daemon (two daemons would drain the replicated queue twice), and the
       xmsg-gateway liveness unit. The other replicas run only kanidmd. The OIDC
       client secrets and the admin password are already environment-scoped
       (`environment.secretPath`), so agenix rekeys them for axon-01 with no
       secret moves. The writer moves in one deploy, once the replicas are in
       sync: uplink's provisioning off, axon-01's on.
     - **Ingress, without nginx on the axons.** kanidm accepts PROXY v2 itself
       (`http_client_address_info.proxy-v2`, trusting the k3s node addresses),
       so envoy can pass TLS through straight to kanidmd on
       `<host address>:8443`. kanidmd terminates TLS with the environment
       certificate from `services.security.acme`, which each replica includes.
       That's four ACME orders for the same certificate, inside Let's Encrypt's
       5-duplicates-a-week limit; a rebuild loop could still exhaust it.
     - **host-upstreams.** It is keyed by host: one listener set, one Backend
       and one TLSRoute per host. Three hosts serving `idm` would produce
       duplicate listeners and routes for one name. It has to group by name
       instead: one listener per name, and a route whose Backend lists every
       host serving that name. The check gains a multi-host case.
     - **Health checks.** Under passthrough envoy can't speak HTTP to kanidm,
       because the TLS is end to end. So use an active TCP check on kanidmd's
       port, plus passive outlier detection on connection failures, in the
       BackendTrafficPolicy. That detects a node or process that is down. It
       doesn't detect a replica that has stopped replicating: a consumer offline
       for more than 7 days needs `kanidmd refresh-replication-consumer`, and
       only its error log says so. That needs an alert from the logs (alloy →
       loki).
     - **LAN DNS (owner, 2026-11-17).** `idm` resolves to uplink's address today
       (10.10.10.1 from the cluster resolver). It moves to the gateway VIP, so
       LAN clients get envoy's failover too, which makes LAN sign-in depend on
       the cluster gateway, as off-LAN sign-in already does. kanidm's book warns
       against DNS-based failover (multiple A records), because clients cache
       them.
     - **xmsg-gateway.** `kanidmHost = "uplink"` feeds `provider_addresses` and
       a `/32` egress rule. It becomes the list of hosts that carry the kanidm
       aspect, with one address and egress rule each. The origin and domain
       lookups take the writer's settings. `xmsg-gateway-check` and
       `blocky-ui-check` read `uplink` by name and move to the writer.
     - **Version lockstep.** Every replica runs the same patched `kanidm_1_11`
       from the same channel. A kanidm bump becomes a coordinated, fleet-wide
       deploy.
   - Execution order: host-upstreams grouping (inert while uplink is the only
     host) → ACME and kanidmd with `[replication]`, no partners, on the axons
     (not yet in DNS or envoy) → commit the certificates and pair with uplink as
     primary → verify sync (a provisioned change on uplink shows up on every
     axon) → envoy backends gain the axons, and LAN DNS points to the VIP → move
     the writer to axon-01 → drop uplink from the partners, the backends and the
     xmsg-gateway list.
   - Progress (2026-11-17):
     - DONE: host-upstreams grouping (840c5d2b); replicas on the axons
       (921d9730); the four-node mesh with uplink as primary (c076198b): every
       pair replicates, and a group created and deleted on uplink appeared and
       vanished on every axon.
     - DONE: the gateway routes idm active/passive (a118f06d, 15d12550): uplink
       active, axon-01 the fallback. kanidm keeps login sessions in each
       server's memory (`IdmServer.sessions`), and passthrough gives envoy no
       cookie, so replicas never share live traffic. Tested: with the gateway's
       connections to uplink rejected for 30 s, idm answered from axon-01 within
       about 10 s while uplink's other names were down, then returned to uplink.
       axon-02 and axon-03 are warm replicas, not routed.
     - DONE: idm resolves to the gateway VIP (18274d53) for LAN and in-cluster
       clients, derived from the replica's upstream record.
     - Incident: the first policy was rejected (a TCP check needs `tcp: {}`), so
       the route ran without PROXY v2 and idm through the gateway (public
       sign-in) reset connections for about 6 minutes, until the fix was applied
       by hand and committed.
     - DONE (2026-11-18): the xmsg-gateway reaches kanidm at the gateway VIP
       (195bf888), not uplink's address.
     - DONE (2026-11-18): axon-01 is the writer (88a17a34): provisioning,
       migrations, mail sender and liveness accounts, served through the gateway
       with no nginx. idm routes to axon-01 (active) and axon-02 (fallback);
       uplink left the route and lost its idm vhost. A group created and deleted
       on axon-01 reached axon-02, axon-03 and uplink within about 30 s
       (replication pulls on an interval). Found on the way: uplink's kanidmd
       lost read access to the wildcard certificate with the writer's nginx
       group (fixed e9803112), and a browser-coalescing 404 through uplink's
       nginx (421 since 4adcb80c).
     - DONE (2026-11-18): uplink's replica retired (0992bf89). The axons
       replicate as a three-node mesh; uplink runs no kanidm (its
       /var/lib/kanidm stays on persist, unused). headscale on uplink reaches
       idm at the gateway VIP and started with its OIDC check passing.
     - DONE (2026-11-18): the PROXY-header log noise. Envoy's TCP health check
       closes the moment it connects (a capture showed SYN, FIN and no bytes),
       so it could never send a PROXY header; PROXY routes are now checked
       passively only (dea41449), and kanidm logs no header errors.
     - Open: nothing probes kanidm's /status. Under TLS passthrough envoy can
       only see TCP; checking /status needs the gateway to terminate and
       re-encrypt idm (BackendTLSPolicy), or an out-of-band probe for alerting.
2. **headscale: move into the cluster, on a CNPG database (owner, 2026-11-17).**
   - headscale is the control plane only (keys, peer lists, endpoints). Peers
     talk to each other directly over WireGuard, so the LAN keeps its 10 Gbps;
     only DERP relays carry traffic, and only for pairs that can't connect
     directly.
   - It can't federate or run active-active: one instance owns the netmap. The
     cluster gives active/standby instead: one replica rescheduled on node
     failure, with its state in a replicated CNPG Postgres (headscale supports
     Postgres) instead of SQLite.
   - uplink is already a single, older host, so the cluster (3 nodes,
     expandable) is strictly better. A cluster outage pauses new logins, key
     renewals and endpoint changes; existing connections keep working.
   - Run DERP separately. `derper` is stateless, so give it independent regions:
     one at home, and one on the Hetzner edge VM (docs/external-vantage-vm.md)
     when it exists. Then relaying survives a home or cluster outage.
   - To scope before execution:
     - SQLite → Postgres migration (pgloader, or re-register nodes);
     - keep the noise private key and server_url, so clients keep their
       identities;
     - public ingress: TCP 443 (the control protocol upgrades the HTTP
       connection) and UDP 3478 (STUN) for in-cluster DERP;
     - OIDC through kanidm, which is also moving;
     - the auth-key generator (below).
3. **DNS: stop depending on uplink. DONE (2026-11-17).**
   - dev resolves through the cluster first, then uplink (90ce49f2, check fix
     d842d351), and the dev network's UniFi DHCP DNS matches (targeted apply).
     cortex, bitstream and cortex-cuda verified.
   - Roaming devices get the cluster first, then uplink (f4986afe), as
     headscale's global nameservers; a tailnet client now lists `10.10.0.53`,
     `10.10.10.1`, then the public resolvers. Both are LAN addresses with no
     tailnet route, so they serve a roaming device on the LAN (verified from
     patch); off the LAN it falls through to the public upstreams, as before.

### Tier 1: degraded, but survivable. Do before the window if time allows.

4. **attic → cluster, on Garage S3 and CNPG Postgres.**
   - This also fixes the SQLite single-connection bottleneck we diagnosed today.
   - Hosts keep working without it (`fallback = true`), just slower, and CI's
     publish steps fail as warnings (xmsg-5dzj.5).
   - Migration: either re-seed the cache or carry the 25 GB of chunks over.
     Re-seeding is simpler; CI rebuilds what it needs.
5. **container-registry → cluster** (registry:2 on Garage S3). Cleared to move
   (owner, 2026-11-17): its consumers are CI (xmsg's images) and nix-config's
   custom container builds.
6. **Host alertmanager → the cluster's** (kube-prometheus-stack already runs
   one). Route host alerts and the SMTP receiver there, and retire uplink's.
7. **Nix builders:** accept. bitstream stays a builder, and hosts build locally.
   No axon builders, to keep the nodes light.
8. **BGP hub: accepted. TESTED (2026-11-17).** uplink's four sessions (the UDM
   and the three axons) were shut for about 3½ minutes. Every 5 s from cortex,
   the gateway (10.11.0.1:443), monitoring-ingest (:443), smtp-relay (:587),
   blocky over BGP (10.11.0.54), coredns (10.11.0.53) and blocky over L2
   (10.10.0.53) all stayed reachable, with no failed probe in 33. The axons'
   default route is a static one via the UDM, and uplink's BGP default is only a
   backup. Sessions were restored with the same prefix counts.

### Tier 2: user-facing, tolerable to lose for the window. Owner's call.

9. **jellyfin:** a separate, scoped migration, not part of this window (owner,
   2026-11-16).
   - The move into the cluster overlaps with the planned Jellyfin 12 upgrade
     (uplink runs 10.11.11), so the two are designed together.
   - It accepts downtime for the window. The library is on the NAS
     (10.10.10.10:/volume2/data), and its 99 GB of state is mostly regenerable
     metadata and image cache.
   - GPU: each axon node has an AMD Phoenix iGPU (/dev/dri/renderD128), and the
     ROCm device plugin advertises it as `amd.com/gpu: 1` per node. llama-cpp's
     `gpt-oss` holds all three today, one replica per node (pods -0/-1/-2 on
     axon-03/02/01). Kubernetes allocates `amd.com/gpu` exclusively, so a
     Jellyfin pod would never schedule.
   - To scope: dedicate one node's iGPU to Jellyfin (drop gpt-oss to 2 replicas,
     plus a toleration or nodeSelector), or share the iGPU through a plain
     `/dev/dri` mount outside the device plugin, and make sure llama-cpp can't
     take it. Also VA-API for Jellyfin on Phoenix (mesa radeonsi) replacing
     uplink's Intel QSV, and the hardware-acceleration settings to match.
10. **open-webui / ollama:** retire, or move open-webui into the cluster pointed
    at the cluster's llama-cpp. ollama isn't serving anything.
11. **homepage, oauth2-proxy, den-docs-mirror, gen-status:** homepage and glance
    already run in the cluster, so retire uplink's homepage. Move the two static
    sites to the cluster. oauth2-proxy retires with the UIs it fronts (envoy
    does OIDC in the cluster).
12. **uplink-dev microVM:** down for the window (owner, 2026-11-16). It's not
    migrated, and den-ag-design work on it pauses.
13. **syncthing:** check whether uplink is the only always-on peer for any
    folder before the window.

## Scoping required before kanidm and headscale move (owner, 2026-11-16)

Both moves are blocked on design work that the summaries above leave out.
(kanidm's provisioning stays NixOS under the replicated design, so its scoping
is now the replication items in item 1.) Each gets a scoped design before any
execution starts.

- **kanidm provisioning.** Today the NixOS module provisions persons, groups,
  POSIX attributes and OAuth2 clients (`services.kanidm.provision` with our
  fork's extra JSON, `kanidm-provision-extra.json`, in
  services/security/kanidm.nix). It's applied by uplink's activation. A pod has
  no NixOS activation, so provisioning needs a new home that nix still renders:
  terranix (a kanidm provider), or a nix-rendered spec applied by an in-cluster
  job or the existing provision tool run against the API.
  - To scope: which tool, how secrets (OAuth2 client secrets, the admin
    credential) reach it, idempotence and drift handling, and how the many
    readers of kanidm host settings (xmsg-gateway's client, the canary account,
    mail sender) move with it.
- **tailscale auth-key generation.** `agenix generate` makes each host's
  `tailscale-auth-key` by ssh'ing to uplink and running `headscale users create`
  and `headscale preauthkeys create` (secrets/_generators-module.nix). Once
  headscale leaves uplink, the generator needs another path to headscale's API.
  - To scope: headscale's remote CLI or gRPC with an API key, or a terranix
    headscale provider; where that key lives; whether pre-auth keys should stay
    reusable with 99-year expiry.
  - This also blocks enrolling any new host while uplink is down.

Order change: the DNS step (3) and the BGP test (8) don't depend on these and
can go first. kanidm and headscale move only after their scoping is approved.

## On promoting bitstream to prod

I wouldn't do it for this. The cluster has an order of magnitude more headroom,
and everything in Tier 0 and Tier 1 fits there. bitstream is already busy and is
a single machine, so moving uplink's single points of failure there only
relocates them. The one case for bitstream is headscale, if a cluster LB proves
awkward for its STUN/UDP and public reachability. That goes away once the edge
VM exists.

## Proposed order

1. DNS changes (3). Smallest, no migration, and they protect the rest.
2. kanidm into the cluster (1). Verify every OIDC client.
3. headscale move plus a second DERP region (2). Verify a roaming device (patch,
   off-LAN).
4. BGP failure test (8).
5. attic, registry, alertmanager (4–6), as time allows.
6. Tier 2 decisions, then the window.

Each step is its own change, with a read-back before the next. Nothing moves
while another step's verification is still open.

## Open questions for the owner

1. Is cluster-first (with bitstream only as the headscale fallback) the right
   default?
2. headscale's home: settled, the cluster on CNPG (see item 2).

Settled: jellyfin accepts downtime and migrates separately, together with
Jellyfin 12; uplink-dev is down for the window.

## Not yet verified

syncthing folder topology. Settled since: the terranix states live in git (the
state passphrases are only decryption keys); the registry's consumers are CI and
nix-config's container builds; uplink's hub default route is only a backup to
the axons' static default.
