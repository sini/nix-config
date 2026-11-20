# Plan: Jellyfin into the cluster

Status: draft v0.1, 2026-11-20. Part of the uplink plan
(docs/uplink-maintenance-plan.md, Tier 2 item 9). Not yet reviewed, and two
owner decisions are open (§6).

## Roles (owner, 2026-11-20)

- **jellarr-0c** owns jellarr: the sini/jellarr fork, its features, upstream
  consolidation and its image. It is responsible for jellarr being able to
  manage our instances. A capability gap found here (first-boot API key, restart
  after plugin install, secret references) is its to close.
- **nix-config** (this plan) owns the rest: the cluster aspect, bootstrapping,
  the Jellyfin settings our aspect renders into jellarr's config, and the live
  migration from uplink.
- Both integration-test and iterate on the deploy and its auto-config.

## What runs today (measured 2026-11-20)

|          |                                                                                                                                                                    |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Service  | declarative-jellyfin (github:Sveske-Juice/declarative-jellyfin) on uplink, Jellyfin 10.11.x from stable nixpkgs (declarative-jellyfin stops at 10.11)              |
| State    | `/var/lib/jellyfin` 99 GB (config, data, metadata, plugins, Shokofin), `/var/cache/jellyfin` 94 MB                                                                 |
| Plugins  | Shoko 6.0.5.11 (Shokofin), SSO Authentication 4.0.0.4 (9p4, provider `kanidm`), TMDb Box Sets                                                                      |
| Library  | the NAS, mounted at `/mnt/data/media` (movies, tv, anime, anime-movies, books, music, mv, concerts)                                                                |
| Hardware | Intel QSV on uplink, through VA-API                                                                                                                                |
| Login    | kanidm OAuth2 client `jellyfin` (redirect `/sso/OID/redirect/kanidm`, `media.access`), the login page's SSO button and CSS; an `Admin` user with a hashed password |

The settings in services/media/jellyfin.nix are the source for §3's config:
network, encoding (VA-API, tone mapping, codecs), trickplay, plugin
repositories, the eight libraries with their fetchers, the user, and the
branding.

## 1. Workload

- **Namespace and app:** a `media` app `jellyfin`
  (kubernetes/services/media/jellyfin.nix).
- **Shape:** one replica, `strategy: Recreate`. Jellyfin's state is SQLite and a
  file tree with a single writer.
- **Image:** upstream `jellyfin/jellyfin`, tracking a major tag through
  `images/`. The move lands on 10.11 first; Jellyfin 12 is a separate step after
  (§5).
- **Volumes:**
  - `/config` and `/data`: a Longhorn volume, 150Gi (99 GB today), in the
    nightly off-cluster backup group.
  - `/cache`: Longhorn single-replica, not backed up (regenerable).
  - The library: `cluster.nfsVolumes.vault-nfs` (immich's pattern), read-only,
    at the same `/mnt/data/media` paths, so library paths in the database stay
    valid.
- **Ingress:** jellyfin.<domain> on the gateway's HTTPS listener, unproxied (no
  Cloudflare limits on streams), with WebSocket upgrade, long timeouts, and the
  client address forwarded (Jellyfin's known proxies = the gateway).
- **Discovery** (7359/udp, DLNA): dropped, since nothing on the LAN depends on
  it. Re-add a LoadBalancer port if a client turns out to.

## 2. GPU (owner decision, §6.1)

Each axon has one AMD Phoenix iGPU (`/dev/dri/renderD128`), advertised as
`amd.com/gpu: 1`, and llama-cpp's `gpt-oss` holds all three, one per node.

- **A. Dedicate one node's iGPU.** gpt-oss drops to 2 replicas, kept off that
  node; Jellyfin requests `amd.com/gpu: 1` and is pinned there. Exclusive and
  predictable. The cost: one inference replica, and Jellyfin can only fail over
  to a node whose GPU is free.
- **B. Share through `/dev/dri`.** Jellyfin mounts the host's `/dev/dri` (render
  group) outside the device plugin and runs on any node, beside gpt-oss. Keeps
  three replicas, but transcodes and inference contend for one GPU, and it needs
  a privileged-ish device mount and a policy exception.

Either way, VA-API on radeonsi (Mesa) replaces QSV. `hardwareAccelerationType`
stays `vaapi`; the codec list is rechecked against Phoenix's VCN 4: AV1 encode
is supported; VC-1 and VP8 decode are not.

## 3. Configuration through jellarr

Interface from jellarr-0c (typedrat/jellarr main @603a5a68, the fork's base):

- **The settings:** nix renders jellarr's YAML from today's settings (network,
  encoding, trickplay, plugin repositories, libraries, the user, branding) into
  a ConfigMap. Unknown keys fail jellarr's validation, so a typo can't silently
  do nothing.
- **Secrets:**
  - `JELLARR_API_KEY` and the SSO client secret come from SOPS-rendered Secrets.
  - The admin password is a `passwordFile`. Jellyfin's API takes plaintext, so
    the nix-declared PBKDF2 hash can't be reused; the admin password becomes an
    agenix secret.
  - The SSO secret goes inside plugin config, which needs the fork's `${VAR}` or
    file-reference form (pending jellarr-0c's syntax).
- **Running it:** a one-shot Job as an Argo PostSync hook, from the fork's ghcr
  image pinned by digest. It re-runs on every sync; jellarr is idempotent. Users
  and libraries are created and updated, never purged, and unlisted ones are
  left alone. The one deletion is of superseded copies of a managed plugin,
  which jellarr-0c is narrowing before release.
- **The API key (owner, 2026-11-20: a generated agenix secret).** Jellyfin's API
  can't take a chosen key value (`POST /Auth/Keys` mints its own), so nix seeds
  it:
  - an agenix secret `jellyfin-api-key` with a generator (32 hex characters,
    Jellyfin's format), delivered to the namespace through SOPS;
  - an init container (sqlite3), before Jellyfin starts, that leaves exactly one
    `ApiKeys` row named `jellarr` carrying that token: it deletes stale
    `jellarr` rows and inserts the current one. The schema is
    `ApiKeys(Id, DateCreated, DateLastActivity, Name, AccessToken UNIQUE)`, read
    from uplink's 10.11 database. Seeding before start means the database is
    never written under a running Jellyfin;
  - it checks the exact columns and fails loudly on a mismatch (a Jellyfin 12
    migration could change them), and upserts by `Name = "jellarr"`, so a
    rotated token replaces the old one;
  - rotation is regenerate, `agenix sops-rekey`, and roll the pod. A restart
    through Jellyfin's API restarts the container, not the pod, so it doesn't
    re-run the seed;
  - the jellarr Job always gets `JELLARR_API_KEY` from that Secret.
  - uplink's database has no API keys (measured), so the migration carries none;
    the seed supplies it.
  - First boot on an empty volume has no database to seed until Jellyfin has run
    once. That one run uses jellarr's password authentication (below), and the
    key is seeded at the next pod start.

- **jellarr features this needs (requested from jellarr-0c, 2026-11-20):**
  - **Password authentication and first boot.** With no `JELLARR_API_KEY`,
    jellarr authenticates as the admin (name plus `passwordFile`). On a pristine
    server it first runs the wizard and creates that admin. No API key is ever
    persisted, and an empty volume configures itself by the same path as a
    normal run.
  - **Restart after plugin changes.** When plugins were installed or removed,
    jellarr POSTs /System/Restart, waits for /health, and re-runs the
    plugin-config pass, all in one Job. A declared plugin whose config can't be
    read fails the run instead of being skipped.
  - **Secret references** in plugin config, `${VAR}` or a file form; nix
    provides both.
- **The admin password** is declarative: an agenix secret, mounted as
  `passwordFile`. uplink's Admin carries a declarative-jellyfin PBKDF2 hash, so
  jellarr reconciles an existing user's `passwordFile`: it tries the login, and
  when that fails, sets the password using the seeded key. The first in-cluster
  run moves Admin to the agenix password. Password authentication remains only
  the fallback for a pristine volume, and when the key is rejected (logged as a
  warning).
- **Network:**
  - The Jellyfin pod needs world egress (443) for its plugin repositories, the
    catalog and metadata providers.
  - The Job needs only the Jellyfin Service (it reads the catalog through
    `/Packages`, and waits on `/health` before its first call).
- **Versions:** one jellarr release for 10.11 and 12. It sends
  `Authorization: MediaBrowser Token=…`, proven on 10.11 in the fork's VM test
  before tagging.

- **The integration test:** a throwaway instance (empty volume, no route), run
  before uplink's data is touched. It must reach a converged state from empty,
  and a second run must report no changes.

## 4. Migration (owner decision, §6.2)

- **Carry the state (default):** stop Jellyfin on uplink, then `rsync -aHAX`
  `/var/lib/jellyfin` into the volume.
  - Use SSH from a temporary pod, not `kubectl port-forward`, which stalled on
    the registry copy.
  - Start the pod and let jellarr reconcile.
  - Users, watch history, API keys and plugin state come across. The paths are
    unchanged (§1), so no rescan is needed.
- **Fresh start:** an empty volume, then jellarr's bootstrap and a full library
  scan. It loses watch history and user settings, and needs §3's first-boot key.

Cutover, in order:

1. Land the app with `live` off (no route, replicas 0).
2. Copy while uplink still serves.
3. Stop uplink's Jellyfin.
4. Copy the delta.
5. Set `live`.
6. Remove `services.media.jellyfin` from uplink and deploy it.

Rollback before uplink's copy is wiped: unset `live` and re-include the aspect.

## 5. After the move

- **Jellyfin 12.** This needs jellarr's Authorization-header auth (upstream #79,
  in typedrat main) and the plugins' 12-compatible releases. It's a separate
  change once 10.11 is stable in the cluster.
- **Cleanup.** Retire declarative-jellyfin and the uplink aspect, then wipe
  uplink's `/var/lib/jellyfin` after a week.

## 6. Open decisions for the owner

1. GPU: A (dedicate one node) or B (share `/dev/dri`). I'd recommend A: it's
   exclusive and predictable, and needs no device-mount exception.
2. Must watch history and user settings survive? I'd recommend carrying the
   state (§4 default). It costs nothing extra, because the paths don't change.

## Not covered

jellarr's internals; Jellyfin 12 itself; the clients.
