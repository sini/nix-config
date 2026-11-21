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

## 4a. Shoko for Shokofin: a declared, rebuildable user (owner, 2026-11-20)

Shokofin authenticates with a Shoko API key, which Shoko issues for a username
and password. The owner wants a dedicated user, declared, and rebuildable on a
fresh cluster. Shoko 5.3.3's API covers this (read from its swagger):

- **Secrets:** agenix generates two passwords, Shoko's admin
  (`shoko-admin-password`) and the dedicated `jellyfin` user's
  (`shoko-jellyfin-password`). Both reach the cluster through SOPS.
- **Bootstrap Job** (the shoko app, PostSync, idempotent):
  - On a pristine Shoko (`GET /api/v3/Init/Status` not `Started`):
    `POST /api/v3/Init/DefaultUser` with the admin credentials, then
    `GET /api/v3/Init/StartServer`.
  - Sign in as admin (`POST /api/auth {user, pass, device}`).
  - Ensure the `jellyfin` user exists, non-admin (`POST /api/v3/User`). If it
    exists, `POST /User/{id}/ChangePassword` to the agenix password, so the
    password is always the declared one.
- **Shokofin's key:** never stored. Before jellarr runs (an init container on
  the jellarr Job; on uplink, an `ExecStartPre` of jellarr's unit), a step signs
  in as `jellyfin` with `device = "shokofin"` and writes the returned key to a
  file. jellarr's config sets Shokofin's `Username` = `jellyfin` and `ApiKey` =
  `{ _file: … }`.
  - jellarr diffs the resolved value, so a key that changes on every run would
    re-post Shokofin's config each run (jellarr-0c). To check when the
    `jellyfin` user exists: does `POST /api/auth` with the same `device` return
    the same key? If it does, the step stays as written. If it doesn't, the step
    first tries the key Shokofin already holds (read through Jellyfin's
    `/Plugins/{id}/Configuration`) against Shoko, and mints a new one only when
    that fails.
- **Built** (kubernetes/services/media/shoko.nix, `shoko-bootstrap`), with these
  facts read from Shoko 5.3.3's source:
  - A sign-in returns the same key for the same user and device, so the key is
    stable and the step above stays as written. The Job signs in with its own
    device, so it never touches Shokofin's key.
  - Changing a password revokes all of that user's keys, so the Job changes
    `jellyfin`'s password only when the declared one fails to sign in. If the
    `jellyfin` user is an admin, the Job demotes it.
  - Shokofin needs no admin rights. Its one admin-only call,
    `GET /api/v3/Settings` (for the web UI prefix), falls back to the default.
- **Adopting the running instance (once):** the live Shoko predates the declared
  admin. Its users are `json` (an admin, which Shokofin on uplink uses today)
  and `Family Friendly`. The declared `admin` was created once through
  `POST /api/v3/User`.
- **Shoko's seeded `Family Friendly` user** is an admin with an empty password,
  created on every install, and Shoko accepts the empty password, so anyone on
  the LAN could get an admin key through the internal LoadBalancer. The Job
  deletes it (owner, 2026-11-21), along with its watch state.
- **On a new cluster:** everything above re-runs from empty, so a fresh deploy
  needs no hand steps for this. Shoko's own library setup (AniDB login, import
  folders) is out of scope here; that's a separate declarative-Shoko question.

## 4b. Database backend: SQLite (owner, 2026-11-20: decided)

**SQLite through this migration (decided below).**

**Why:**

- Jellyfin has no official PostgreSQL support. 10.11 added a database-provider
  plugin interface, and the only provider is JPVenson/Jellyfin.Pgsql.
- Its author calls it "HIGHLY experimental… NOT meant for a production jellyfin
  server", and says official support is the goal for Jellyfin 13.0.
- Its Jellyfin 12 support is broken today (issue #47, open, read 2026-11-20):
  - `12.1-1` fails to start, both on a fresh install and upgrading from
    10.11.11: uuid casts with no `USING` clause, foreign keys failing on
    orphaned rows, `min(uuid)` and `json_valid` missing on PostgreSQL.
  - Its backup restore reported success without restoring, until PR #49.
  - There is no 12.2 image. 12.4 works only through an unmerged PR (#50) that
    needs another unmerged upstream change and hand-made indexes.
  - The author supports only latest-to-latest container upgrades.
- Its SQLite → PostgreSQL migration is a documented "ADVANCED, UNTESTED"
  pgloader run.

**What that would mean here:**

- Step 2 (10.11 → 12) would hinge on the plugin's migrations.
- Every later Jellyfin upgrade would wait for a matching plugin image.
- A failed upgrade would sit behind a restore path with a history of false
  success.
- That's the opposite of what the reordered plan is for.

**Other candidates, also rejected (read 2026-11-20):**

- **BORNIOS/Jellyfin-Database-Providers-Postgres** (v3.1.0, 2026-10-19). It's
  the better-built Postgres provider: a plugin with no core changes, a two-way
  SQLite ⇄ PostgreSQL migration tab, and a one-click rollback. It was rejected
  because:
  - it trails Jellyfin: its 3.x targets 12.1, while Jellyfin is at 12.4
    (2026-10-26);
  - 10.11 → 12 is a manual round trip: export to SQLite on 2.0.1, upgrade
    Jellyfin, re-import on 3.x;
  - it has one maintainer;
  - issue #5 (open since 2026-09-18): it needs the PostgreSQL client tools
    inside the Jellyfin image, so the stock image won't do;
  - #9 (fixed in 3.0.4) dropped migration history on our exact path.

  The first to try once the cluster move is done, if it has a release for the
  Jellyfin we run.

- **tursodatabase/turso** (v0.8.4, 2026-11-20): a Rust rewrite of SQLite,
  pre-1.0, with SQL and C API compatibility both "partial" by its own COMPAT.md.
  Rejected because:
  - Jellyfin reaches SQLite through EF Core and `Microsoft.Data.Sqlite`, and
    Turso's .NET package is a separate ADO.NET library with no EF Core provider;
  - its gain is concurrent writes, and Jellyfin is one writer;
  - partial compatibility puts the risk inside Jellyfin's EF migrations.

**Decision (owner, 2026-11-20): SQLite.** Revisit only when Jellyfin supports
another backend officially, or when the BORNIOS provider is current for the
version we run and works on the stock image.

**What SQLite costs instead:**

- One writer, which fits a single replica.
- Backups are Longhorn volume snapshots of a database that's open while they
  run. So the `jellyfin-db-backup` CronJob runs at 02:30 UTC, before the 03:00
  volume backup. It copies each `/config/data/*.db` to `/config/backup` with
  SQLite's online backup API and checks the copy's integrity before it replaces
  the last one, so a restore doesn't depend on WAL recovery.

**When to revisit:**

- When Jellyfin ships an official PostgreSQL provider (13.0 is the stated aim),
  the move is its own step: an empty CNPG cluster, Jellyfin's supported
  migration path, run against a copy first.
- The cluster already runs CNPG for immich, paperless, attic and the rest, so
  the database side is routine. The risk is entirely in Jellyfin's provider.

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
