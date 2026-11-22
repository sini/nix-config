# Plan: Jellyfin into the cluster

Status: draft v0.1, 2026-11-20. Part of the uplink plan
(docs/uplink-maintenance-plan.md, Tier 2 item 9). Not yet reviewed, and two
owner decisions are open (§6).

## Order (owner, 2026-11-20, revised)

The move becomes three steps, each verified before the next:

1. **uplink: declarative-jellyfin to jellarr, on Jellyfin 10.11.** uplink's
   aspect moves to nixpkgs' `services.jellyfin` configured by jellarr's NixOS
   module, with the same settings, against the existing database. This tests and
   validates jellarr's NixOS module for the community, and our aspect stays. Its
   steps become the migration guide upstream asks for (venkyr77/jellarr#84).
2. **uplink: Jellyfin 10.11 to 12**, through jellarr, with a ZFS snapshot of
   `/var/lib/jellyfin` first.
3. **uplink to the cluster: data only.** Both ends run Jellyfin 12, configured
   from the same settings, so this is a copy of `/var/lib/jellyfin` (§4), not a
   reconfiguration.

The settings are written once, in a shared helper (the Jellyfin aspect's
`settings.jellarr`), and rendered into jellarr's YAML for both uplink's NixOS
module and the cluster's Job. The cluster's staged clean install at
jellyfin-next (1bc7cb84) stays for validating the cluster side against the same
settings.

## Roles (owner, 2026-11-20)

- **jellarr-0c** owns jellarr: the sini/jellarr fork, its features (the NixOS
  module included), upstream consolidation, its image, and the migration guide
  (#84), written from step 1. It is responsible for jellarr being able to manage
  our instances. A capability gap found here (first-boot API key, restart after
  plugin install, secret references) is its to close.
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
  - The SSO secret goes inside plugin config as a mounted file, named by a
    structured file reference.
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
  - **Secret references** in plugin config: a structured file reference,
    `{ _file: "/path" }`, replaced after parsing by the file's trimmed contents
    (a missing file is an error). No env substitution: it pasted values into raw
    YAML, where a secret could alter the config. The key name is final with the
    release.
  - jellarr also expands `${VAR}` after parsing, in any string value; `$$` is a
    literal `$`, and a missing variable fails the run. So nix escapes every `$`
    in the strings it renders (the login page's HTML and CSS included), and uses
    file references, never `${VAR}`, for secrets.
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

- **The anime libraries are Shokofin's** (measured on uplink, 2026-11-21):
  - **Before the fix:** Anime (shows) and AnimeMovies are the Shoko-backed
    libraries, shows and movies apart (Shokofin's `SeparateMovies`). Their items
    under Shokofin's VFS (378 series, 9,195 episodes, 282 movies) carry AniDB
    and Shoko IDs. But no library had Shoko as a metadata fetcher. The fetchers
    had been left at TheMovieDb and OMDb, the declarative-jellyfin shape.
    Shokofin manages a library only when Shoko is one of its fetchers
    (`ShokoIdLookup.IsEnabledForLibraryOptions`, 6.0.5), so it had dropped every
    library from its config (`Libraries` empty in its XML, already so in the Nov
    19 backup). The VFS was empty, and the physical anime folders were being
    scanned as plain TheMovieDb media (400 series, 438 movies with no AniDB ID).
  - **The declaration now:** Anime and AnimeMovies carry Shoko as their only
    metadata fetcher and first image fetcher, followed by Screen Grabber for
    episodes and movies. The embedded title and episode info options are off.
    This is what Shoko's docs recommend.
  - **Paths:** with the VFS on, Shokofin replaces the media path with its VFS
    root. So both libraries set `ignoreChanges = [ "pathInfos" ]`. The physical
    path is used only to create the library, on a fresh server, and Shokofin
    takes it over from there. The `jellyfin-settings` check holds both rules.
  - **Expected on uplink's first jellarr run:** Shokofin picks the two libraries
    back up and rebuilds the VFS, and the next scan replaces the TheMovieDb
    copies. Shoko's docs say that enabling Shokofin on an existing library isn't
    supported. These two were Shokofin libraries before (the VFS links carry
    their IDs), but watch the first scan.
  - **Left out of the config, live leftovers jellarr can't see:** jellarr
    compares a library's `PathInfos`, not the `.mblink` files Jellyfin scans.
    Shows still has an `anime.mblink`, so it also scans the anime folder. Movies
    still links an empty VFS root. Books, Music, MusicVideos and Concerts each
    list their folder twice. All of these were left by declarative-jellyfin.
    jellarr 0.3.1 reconciles `Locations` with the declared paths (jellarr-0c).
    They stay as they are until then, so its dry run shows them as the
    real-world test. Don't clean them by hand.
- **The integration test:** a throwaway instance (empty volume, no route), run
  before uplink's data is touched. It must reach a converged state from empty,
  and a second run must report no changes.

## 3a. Jellyfin 12 on uplink (done 2026-11-21, nix-config 9750c5a5)

- **Plugins:** SSO Authentication 5.1.1 from K0lin's fork (9p4's has no 12
  build; same GUID 505ce9d1 and configuration, which carried over), Shokofin
  6.0.5.4012 from its dev channel (owner), and TMDb Box Sets 15.0.0.0. Each is
  pinned to its repository with jellarr 0.3.3's `repository`.
- **Before the upgrade:** ZFS snapshot
  `zroot/local/persist@pre-jellyfin12-20261121T224829Z`, and
  `/root/jellyfin.db.pre-jellyfin12-20261121T224829Z` (sqlite .backup, integrity
  ok, 143,198 items).
- **The migration:** about 10 minutes, then a database optimise. During it,
  /System/Info/Public answers 200 but authenticated calls return 503. jellarr
  0.3.3 failed on that, and 0.3.4 retries 503. The run after it converged (exit
  0).
- **What MigrateLinkedChildren removed:** 2,291 rows.
  - 2,035 extras and trailers, about half of whose files still exist; a rescan
    re-adds those.
  - 251 movies under the old Movies VFS root, unlinked by jellarr 0.3.1; they
    live under AnimeMovies now.
  - Watch state on 10 trailers and 3 of those movies.

- **What actually removed the 240 anime movies:** Kubernetes liveness-killed
  Shoko twice mid-scan (1 s probe timeout under Shokofin's per-file API load).
  Every lookup refused during a restart left a file out of AnimeMovies' VFS, and
  the migration then dropped the stale items. Fixed in 94e7ff9d: liveness 15 s ×
  10 at 30 s, readiness 5 s.
- **After the probe fix (2026-11-21):**
  - The AnimeMovies VFS went from 39 to 350 links, 283 movies (282 before the
    upgrade). Returned items keep their old ids, since Jellyfin derives them
    from the path, but their UserData rows don't come back.
  - Restored from the backup through POST /UserItems/{id}/UserData, each read
    back equal: 3 rows on those movies, and 17 episode rows that were on Shows'
    duplicate anime copy (the stale anime.mblink jellarr 0.3.1 removed), moved
    to the Anime VFS item for the same file.
  - Not restored: 6 rows on trailer entries.
  - 132,591 items now. The difference is mostly that duplicate copy (7,945
    episodes, 400 series) and extras.
- **Rule for later jellarr plans:**
  - An unlink in a dry run ("its items leave the library on the next scan") is
    safe only when what replaces it is fully populated BEFORE that scan. Check
    the VFS link count against Shoko's matched files first.
  - Items that come back are new library items. Spot-check that watched and
    progress state reattached. If it didn't, recover the UserData rows from the
    pre-upgrade backup.

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

## 4. Done: Jellyfin runs in the cluster (2026-11-22, nix-config 4381b88a)

- **The move:** a ZFS snapshot
  (`zroot/local/persist@pre-k8s-move-20261122T060727Z`). Then uplink's Jellyfin
  and jellarr were stopped, and `/var/lib/jellyfin` (17 GB, without
  declarative-jellyfin's 81 GB `backups` and the log) and `/var/cache/jellyfin`
  were tarred to the NAS. The tars were sha256-checked and unpacked by a
  temporary pod into `jellyfin-data` (Longhorn, 40Gi) and `jellyfin-cache`; the
  tars were deleted after.
- **Layout:** the pod keeps uplink's paths
  (`JELLYFIN_DATA_DIR=/var/lib/jellyfin`, cache `/var/cache/jellyfin`) and
  mounts the same NFS export at `/mnt/data`, so the database needed no rescan.
- **Read-back:**
  - the same server id (9550a7ff…), Jellyfin 12.4.0, 20 users;
  - 4,155 movies, 484 series, 11,498 episodes;
  - Shokofin VFS 9,540 links; the 17 restored watch rows intact;
  - SSO-Auth 5.1.1, Shoko 6.0.5.4012 and TMDb Box Sets 15.0.0.0 all Active;
  - a VA-API decode and encode on the Radeon 780M;
  - jellarr's first container run (v0.3.5 Job) applied only the cluster's
    encoder codecs and proxy range;
  - jellyfin.json64.dev now resolves to the cluster gateway, and its SSO start
    redirects to kanidm.
- **Rollback:** uplink's copy is gone (cleanup, owner, 2026-11-22); restore from
  the cluster volume's Longhorn backup instead.
- **Closed (owner, 2026-11-22):** SSO sign-in confirmed on the cluster copy.
  Cleanup done: the stale staged volume pvc-1883f620 (150Gi; PV and Longhorn
  volume); uplink's `/persist/var/lib/jellyfin` (98 GB with the old
  declarative-jellyfin backups); the pre-jellarr, pre-jellyfin12 and
  pre-k8s-move snapshots; the database backups in uplink's `/root`; uplink's
  rekeyed Jellyfin secrets. The cluster volume is now the only copy, kept by
  Longhorn's nightly media-config backup and the 02:30 jellyfin-db-backup copy
  before it. stale staged volume pvc-1883f620 (150Gi) is deleted, PV and
  Longhorn volume. Still to go when the owner is ready: uplink's
  `/persist/var/lib/jellyfin`, and the pre-jellarr and pre-jellyfin12 snapshots.
