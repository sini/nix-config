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

1. **kanidm: move into the cluster.**
   - Run it as a single-replica StatefulSet on a 2-replica Longhorn volume
     (state is under 1 MB), behind the envoy gateway at idm.json64.dev.
   - A node failure then reschedules it. That's enough HA for a homelab IdM.
     kanidm's own replication is the follow-up if we want two live instances.
   - Changes: a kubernetes aspect; DNS for idm; the xmsg-gateway aspect's
     `kanidmHost` model (it assumes a host IP for egress) becomes an in-cluster
     service; the mail sender relays through the cluster's smtp-relay, which
     already exists.
   - Migration: stop kanidm on uplink, copy its database, start it in the
     cluster, flip DNS. Downtime is minutes.
   - Risk: every OIDC client's issuer URL stays the same (same hostname), so
     clients shouldn't notice. Verify one client of each kind afterwards
     (grafana, argocd, the gateway).
2. **headscale: move off uplink, to the cluster or bitstream.**
   - It can't run two instances (one SQLite database, one control server), so
     the goal is to put it somewhere that stays up.
   - In the cluster it needs a LoadBalancer IP with TCP 443 and UDP 3478 (STUN),
     and public reachability for roaming clients at the same server_url.
   - Copy the database and the noise private key unchanged. Clients reconnect to
     the same URL and keep their identities.
   - Add a second DERP region now, and run it on the planned Hetzner edge VM
     (docs/external-vantage-vm.md) when that exists. Then a home outage no
     longer takes roaming relay with it.
   - What an outage costs if this slips: existing tailnet sessions keep working,
     but new logins, key renewals and roaming endpoint changes fail, and peers
     that need DERP can't reach each other. For a multi-day window that's
     significant, especially for patch away from home.
3. **DNS: stop depending on uplink.**
   - Add `axon` to the dev environment's `dns.resolvers`. It's uplink-only
     today, so dev hosts (cortex, bitstream, patch) lose DNS with uplink.
   - Prove the axon resolver's LB is reachable over the tailnet, then add it to
     `dns.roamingResolvers`. That was the documented precondition.
   - Prod already lists axon first.

### Tier 1: degraded, but survivable. Do before the window if time allows.

4. **attic → cluster, on Garage S3 and CNPG Postgres.**
   - This also fixes the SQLite single-connection bottleneck we diagnosed today.
   - Hosts keep working without it (`fallback = true`), just slower, and CI's
     publish steps fail as warnings (xmsg-5dzj.5).
   - Migration: either re-seed the cache or carry the 25 GB of chunks over.
     Re-seeding is simpler; CI rebuilds what it needs.
5. **container-registry → cluster** (registry:2 on Garage S3). First list who
   pulls from registry.json64.dev.
6. **Host alertmanager → the cluster's** (kube-prometheus-stack already runs
   one). Route host alerts and the SMTP receiver there, and retire uplink's.
7. **Nix builders:** accept. bitstream stays a builder, and hosts build locally.
   No axon builders, to keep the nodes light.
8. **BGP hub:** accept, after a test. The axons peer with the UDM directly and
   advertise their LB routes there. Before the window, drop uplink's sessions
   for a minute and confirm LB services stay reachable from the LAN.

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

Both moves are blocked on design work that the summaries above leave out. Each
gets a scoped design before any execution starts.

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
2. headscale's home: open (owner, 2026-11-16). Agreed against the cluster: it
   would make remote access to a broken cluster depend on that cluster, it needs
   public TCP 443 plus UDP 3478 behind extra LBs and port forwards, and it can't
   replicate. Options are the Hetzner edge VM (removes the single point of
   failure; needs the VM to exist first) or bitstream for the window (same NixOS
   module; a temporary single point of failure off the maintained box).

Settled: jellyfin accepts downtime and migrates separately, together with
Jellyfin 12; uplink-dev is down for the window.

## Not yet verified

Where the terranix states live (the dns/unifi/github state passphrases are
uplink aspects); registry.json64.dev's consumers; syncthing folder topology;
uplink's role in the hub-originated default route.
