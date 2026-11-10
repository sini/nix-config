# MicroVM guests: a persistent store over the host's shared store

Status: **draft v0.9.1** (2026-11-10). v0.7.1, which the review capped at
round 6 and which is implemented as rollout commits 1–2 (§2.9), plus **§2.10:
guest state on block volumes**. That section answers the owner: "it will easily
pass 4 million if it starts working on parallel trees". §2.10 has had three
review rounds, with 12, 4, 6 and 6 surviving objections. v0.9 removed round 8's
rollback machinery and made the migration one-way. v0.9.1 applies round 10's
fixes, which concern the crash ordering, a guest whose first backend is zvol,
and how a refused start is reported. That revision has not been reviewed. Owner request:
"the devshell loss on every reboot is really painful; we need a real solution
for persistence." §8 maps every earlier objection to its resolution.

## 1. Problem

A build-capable microvm guest (today: `uplink-dev`) loses every store path it
builds or fetches at each VM start. Its devshells, nix-direnv profiles and
`--out-link` roots then point at paths that no longer exist, so the first `cd`
into a repo rebuilds or refetches the whole devshell.

How the guest's store is assembled today (`virtualization/microvm-guests.nix`,
`hosts/uplink-dev.nix`):

- `/nix/.ro-store`: the host's `/nix/store`, read-only over virtiofs
  (`sharedNixStore`, default on).
- `/nix/.rw-store`: a `scratchVolumes` ext4 image on the host's `/cache`. An
  `ExecStartPre` on `microvm@<guest>` deletes it, so it is recreated empty at
  every start.
- `/nix/store`: an OverlayFS of the two (`microvm.writableStoreOverlay`).
- The Nix database: on the guest's tmpfs root, holding only the guest's system
  closure (`microvm.registerClosure`).

microvm.nix documents this as the recommended shape (`doc/src/shares.md`): "The
Nix database will forget all built packages after a reboot … it is recommended
to just delete and recreate the overlay."

The layout also duplicates. The guest's database doesn't know which paths the
host has, so a devshell input the host already holds counts as invalid and is
fetched again into the upper layer. Measured on uplink-dev on 2026-11-09: **1024
of the 4879 upper paths also exist in the lower layer.**

**Why the overlay can't simply be kept.** The host garbage-collects the lower
layer: nightly with `nix-gc` at 05:00 (`core/nix/nix.nix:129`), through the
daemon's `min-free` auto-GC, and with manual GCs. None of these sees the guest's
roots. A persisted guest database would keep claiming host paths valid after the
host deleted them. The database says valid, the file is gone, and nothing
reports it.

**Constraint:** don't replicate the store, so a guest-private full store is out.

## 2. Design

1. **The guest's store becomes Nix's `local-overlay` store, with the host's
   daemon as its lower store.** The guest reads lower validity live from the
   host's database, so it never refetches what the host has. Its database, upper
   layer and state persist together on one volume.
2. **The guest exports the host-side part of the closure of everything it
   depends on, and the host keeps that set as permanent GC roots.** "Everything
   it depends on" means its GC roots and its own built paths. Every host GC
   honours these roots: nightly, `min-free` and manual.
3. **A reconcile in the guest repairs what it depends on, then drops stale
   rows.** It runs 5 minutes after boot and then every 15 minutes:
   - Every lower path the guest depends on that the host no longer holds valid
     is re-substituted, one path at a time, references first. Substitution only,
     never a build.
   - A dependency that no substituter has, on 3 consecutive fresh lookups, is
     given up. Its auto roots are removed, and the guest's own GC decides what
     dies; nix-direnv rebuilds it on next use.
   - Nix's own `nix-store --verify` (no repair) then drops the stale rows.

   Any other failure fails the unit, and the fleet's existing failed-unit alert
   fires.

### 2.1 The store (guest)

`local-overlay` (Nix 2.34.9, experimental feature `local-overlay-store`, see
`nix help-stores`) is a local store whose store directory is an OverlayFS. Its
upper database holds the upper layer's paths plus a copy of the metadata of
every lower path it has checked: `isValidPathUncached` falls back to
`lowerStore->isValidPath` and copies the closure's rows
(`src/libstore/local-overlay-store.cc`, 2.34-maintenance). Its GC deletes only
the upper layer. A path present in both layers is deleted through the upper
directory, so no whiteout is created, and `remount-hook` runs afterwards.

**Volume.** One persistent volume, `/nix/.rw-store`: an ext4 image at
`<scratchRoot>/<guest>-nix-store-e<epoch>.img` on the host's `/cache`, sparse,
`size` MiB.

| Path in the volume | Role                                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------------------------- |
| `store/`           | OverlayFS upper directory (microvm.nix's `writableStoreOverlay` layout, unchanged)                      |
| `work/`            | OverlayFS work directory (unchanged)                                                                    |
| `var/nix/`         | bind-mounted onto `/nix/var/nix` (`neededForBoot`): the database, gcroots, profiles, temproots, gc.lock |

The guest runs a systemd initrd, so its stage-1 mounts are prefixed with
`/sysroot`. The bind's source has to exist before the bind mounts. The guest
fragment therefore emits an initrd unit, `rw-sysroot-nix-var-nix`, that mirrors
nixpkgs' own overlay mkdir unit
(`nixos/modules/tasks/filesystems/overlayfs.nix`). Its settings:

- `requiredBy` and `before` on the bind's mount unit;
- `RequiresMountsFor=/sysroot/nix/.rw-store`;
- `ExecStart`: `mkdir -p -m 0755 /sysroot/nix/.rw-store/var/nix`.

On a fresh image the guest therefore boots empty and starts from there.

**Store selection.** Only the guest's `nix-daemon` opens the local-overlay
store:

- Every client, root included, gets `store = daemon` from
  `nix.settings.store = mkForce "daemon"` in the guest fragment. NixOS sets no
  `NIX_REMOTE`, and for root `auto` resolves to a local store (verified in round
  3), so this setting is required. Test 8 checks it.
- The daemon's unit sets `NIX_USER_CONF_FILES=/etc/nix-daemon/store.conf`. User
  configuration files load after `/etc/nix/nix.conf`, so their `store` wins. The
  file holds exactly one line:
  `store = local-overlay://?lower-store=<lower>&upper-layer=/nix/.rw-store/store&check-mount=false&remount-hook=<hook>`,
  where `<lower>` is `unix:///run/nix-lower/socket?real=/nix/.ro-store`
  (URL-encoded, §2.2) and `<hook>` runs `mount -o remount /nix/store`.
- The daemon's `restartTriggers` gain the file.
- `NIX_CONF_DIR` is left alone. It would move the default
  `builders = @$NIX_CONF_DIR/machines`, and so silently switch off the guest's
  remote builders (round 3, measured).
- The URL is in a file, not in `Environment=`, so systemd's `%` specifiers never
  see it.

`check-mount=false` is needed because Nix matches `lowerdir=/nix/.ro-store`
against `/proc/self/mounts`, and under the systemd initrd that file reads
`lowerdir=/sysroot/nix/.ro-store` (measured on uplink-dev). The reconcile checks
the mount itself (§2.6 step 0). Because the daemon is the only process that
opens the store, a root `nix-collect-garbage` runs the overlay GC inside the
daemon. Nothing opens the overlay directory as a plain local store (I5).

Two more settings complete the store:

- `extra-experimental-features = local-overlay-store`.
- **Build directories.** Nix's default `build-dir` is `<state>/builds`, which is
  now on the persistent volume. The initrd unit `rw-sysroot-nix-var-nix` empties
  `/sysroot/nix/.rw-store/var/nix/builds` (`rm -rf`) before its `mkdir`, so it
  is boot-only by construction, as the tmpfs root was. A build killed mid-way,
  or one kept with `--keep-failed`, can't then accumulate across boots (round
  4). No tmpfiles rule is added. Nix's own `d /nix/var/nix/builds … 7d` (nixpkgs
  `nix-daemon.nix`) keeps its 7-day bound between boots, and a second line for
  the same path would collide with it (round 6).
- An assertion in the guest fragment: `config.microvm.hypervisor` is one of
  `qemu`, `kvmtool` or `alioth` or `crosvm`, the runners that attach
  `vhost-vsock`. Under cloud-hypervisor a CID-2 connection lands on a host unix
  socket, not on AF_VSOCK, so the lower channel would reach nothing (round 5).
- `microvm.registerClosure = false`. The system closure is valid in the host's
  database and rooted there through the host's `current` runner link. Loading it
  into the upper database would add every past system generation to the guest's
  database for good.

**Probe** (bitstream, 2026-11-09, unprivileged user namespace, over its own
store). A `local-overlay` store with
`lower-store=daemon?real=<bind of /nix/store>`:

- opened, and answered `path-info` for a path only in the lower layer;
- copied a 6357-path lower closure into the upper database when one derivation
  naming that closure was instantiated;
- inflated the upper database to 293,353 rows (the host store has 293,476
  entries) under a `--dry-run` GC. A real GC then took 293 s and left 43,935
  rows. §2.3 is built not to depend on that row count.

### 2.2 The lower channel (vsock)

The lower store's metadata must be live. Sharing the host database read-only
over virtiofs gives wrong answers: Nix's `read-only` setting warns of "incorrect
query results or corruption errors if the database is changed by another
process", and SQLite's WAL index can't be shared across a VM boundary. The
channel is therefore the host's `nix-daemon`, carried over AF_VSOCK.

**Host side,** emitted on a host with at least one persistent-store guest:

- `boot.kernelModules = [ "vhost_vsock" ]`, so the listener can bind at boot.
- `microvm-nix-lower.socket`: `ListenStream=vsock::5119`.
- Its service runs `systemd-socket-proxyd /nix/var/nix/daemon-socket/socket` as
  a `DynamicUser`. The host daemon sees an untrusted user:
  `allowed-users = [ "*" ]` (`nix.nix:122`), and the user is not in
  `trusted-users`.
- `microvm@<guest>` gets `Wants=` and `After=` on `microvm-nix-lower.socket`.
  Not `Requires=`: a restarted listener must not stop the guest, which treats a
  missing lower store as transient (test 12).

**Guest side:**

- `nix-lower.socket`: `ListenStream=/run/nix-lower/socket`, `SocketMode=0600`,
  `Accept=yes`.
- `nix-lower@.service`: `socat STDIO VSOCK-CONNECT:2:5119`.
  `systemd-socket-proxyd` can't dial vsock (`man systemd-socket-proxyd`, systemd
  262).
- `nix-daemon.service` gets `Requires=` and `After=` on `nix-lower.socket`.
- Setting a CID also makes systemd's ssh-generator listen on `vsock::22` in the
  guest. That reaches only from the host, whose root already controls the guest,
  so it is accepted and named here.

**Trust edge.** The guest is already a `remote-build-client` of uplink, holding
`nix-remote-build-user-key`, so it can reach `nix-store --serve --write` as
uplink's trusted `nix-remote-build` user. The vsock channel therefore adds less
than it seems (round 6). Through it, guest root becomes an untrusted user of the
host's daemon. It can query, build derivations in the sandbox as `nixbld`, and
add whatever an untrusted user may add. It can't touch anything outside the
store. The lower store needs only queries, but Nix has no read-only daemon mode.
The guest already has the LAN and its own build capacity, so this adds host CPU
and store space and nothing more.

Every guest on the host can reach the port, so the rule is host-wide: a host
with a persistent-store guest may carry only guests whose `system-owner` is the
host's (assertion). Today that holds, since uplink-dev is uplink's only guest.

### 2.3 Root export (guest)

`nix-store-roots-export.service` (oneshot, `TimeoutStartSec=5min`) computes

> **E** = { p ∈ closure⁺(R) ∪ closure(U) : p has no entry in the upper layer }

where:

- **R** is the guest's GC roots, as the guest GC itself finds them:
  `nix-store --gc --print-roots`. That covers gcroots (nix-direnv's indirect
  roots included), profiles, runtime roots from `/proc`, and temp roots.
  `findRoots` calls `isValidPath` on each root target, which also syncs that
  root's closure rows.
- **U** is every valid path present in the upper layer: an entry in
  `/nix/.rw-store/store/` that `nix path-info` accepts. A whiteout (a character
  device) is not an entry here, neither for U nor for E's filter: a whited-out
  host path stays exported until the reconcile scrubs the whiteout (§2.6 step
  1).
- **closure⁺** is `nix-store --query --requisites --include-outputs`, which
  matches the guest's inherited `keep-outputs = true` for what its roots keep.
  **closure** is plain `--requisites`. Those references are exactly what the
  schema's foreign keys hold the upper paths to. `--include-outputs` is not
  applied to U: a dead upper `.drv` would pull in the outputs of its whole build
  closure (round 3).
- **Cap:** if |E| exceeds `maxExportPaths`, the export does not write. The
  previous file stays in place (the host keeps applying the last full set) and
  the unit fails, which alerts. Nothing is ever truncated, so the host never
  applies a partial set (round 4).

Below the cap, E holds every host path the guest depends on: each upper path's
closure and each root's closure. It does not depend on how many lower rows the
database has accumulated. A dry-run or `--print-live` GC that inflates the
database changes nothing in E, and neither does a GC that dies partway (round 2,
objections nix-1 and secops-1). The export takes no lock.

E is written sorted to `/run/microvm-exchange/store-roots`, through a temp file
and a `rename`, but only when its content changed. That directory is the
guest's **exchange share** (§2.10), a small virtiofs share of
`/var/lib/microvms/<guest>/exchange` on the host, which exists only to carry
files between guest and host. It replaces the guest's `/cache` share, which a
block-volume guest no longer has. Writes are so an idle guest triggers no host
import. The timer has `OnBootSec=1min` and `OnUnitActiveSec=1min`, with no
ordering on the reconcile, so a long repair never delays it (round 4). Test 13
records how long a run takes.

### 2.4 Root import (host)

Per persistent-store guest:

- `microvm-store-roots@<guest>.path`: `PathChanged=` on the guest's export file.
  virtiofsd writes the file on the host, so the host's inotify sees the change.
- `microvm-store-roots@<guest>.timer`: every 15 minutes, as a backstop.
- `microvm-store-roots@<guest>.service`: oneshot, `RemainAfterExit=no`,
  `TimeoutStartSec=infinity` (step 4). It runs a host program
  (`writers.writePython3Bin`), in five steps:

1. **Open without following anything the guest controls.** Take a directory fd
   on the guest's host-owned exchange directory
   (`/var/lib/microvms/<guest>/exchange`, root-owned, 0700). From it, open
   `store-roots` with
   `O_RDONLY|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC`. `fstat` that fd and require
   `S_ISREG`. Read it once, through the fd, at most `256 × maxExportPaths`
   bytes. A symlink, FIFO or device is refused before any read can block. A
   missing `store-roots` (a guest that has not exported yet) is
   not an error: nothing is applied, the previous set stays, and the unit
   succeeds.
2. **Parse strictly.** Every line must match
   `^/nix/store/[0-9a-df-np-sv-z]{32}-[0-9A-Za-z+\-._?=]{1,211}$`. If a line
   doesn't match, or there are more than `maxExportPaths` lines, the whole file
   is rejected: the unit fails and the previous root set stays as it was. The
   cap counts paths, not bytes. It guards against a runaway or buggy export
   pinning the whole store and stalling the host's GC. A guest that adds huge
   paths through the daemon can still pin them. That exposure is accepted under
   the same-owner rule (§2.2), and a byte bound is not built (round 3, necessity
   pass).
3. **Check existence on the host.** `lstat` (no follow) each
   `/nix/store/<base>`. A missing path is skipped and counted in the log: the
   host had already lost it, and the guest's reconcile owns it.
4. **Apply under the host GC lock, shared, blocking.** `flock(LOCK_SH)` on
   `/nix/var/nix/gc.lock`, and the service has `TimeoutStartSec=infinity`. A
   long host GC can therefore never time the import out (round 5). The import is
   never skipped either. A skip would let a second GC run on stale roots, back
   to back under disk pressure, without any unit failing (round 6). While the
   import waits, systemd coalesces the path unit's triggers, and `nix-gc`'s
   `After=` waits for the apply. Every `collectGarbage` takes that lock
   exclusively before it reads permanent roots (`src/libstore/gc.cc`: "Since
   we've grabbed the GC lock, the set of permanent roots cannot increase now"),
   so a GC sees the old set or the new one, never half of either. In
   `/nix/var/nix/gcroots/microvm-store/<guest>/`, create the missing
   `<base> → /nix/store/<base>` symlinks first, then remove the ones that are no
   longer listed. Link names are validated basenames, so they can't traverse out
   of the directory. There is no staleness check (round 5, necessity pass). A
   hung or stopped guest leaves its last set in force, which is the safe
   direction. A hung guest also trips the fleet's `HostSilent` alert, and an
   export that can't be written fails the guest's own unit.

Around the units:

- `nix-gc.service` gets `Wants=` and `After=` on each guest's import, so the
  nightly GC starts from a fresh set. Protection doesn't depend on that
  ordering: the roots are permanent and every GC kind reads them.
- A stopped or crashed guest keeps its last set, so it stays protected while
  down.

**Sweep,** on every `virtualization.microvm-host`, so it outlives the last
persistent guest. `microvm-store-sweep.service` is a oneshot with
`RemainAfterExit=yes`, so switch-to-configuration restarts it whenever its
`restartTriggers` change. Its trigger is the keep-set below. It runs at boot and
after every change to the keep-set:

- **keep-set:** every image the current configuration names under `scratchRoot`
  (scratch and persistent, at their current epochs), and the gcroots directory
  of every enabled persistent-store guest.
- It deletes every `<scratchRoot>/*.img` and every `gcroots/microvm-store/*` not
  in the keep-set. This also covers what the per-guest migration rule did: the
  old `<guest>-nix-rw-store.img` is not in the keep-set. So no migration
  `ExecStartPre` is emitted.
- It is ordered `After=` every `microvm@<guest>.service`. An epoch bump also
  restarts the guest: `microvm@<guest>` gets the image path in its
  `restartTriggers`, and its default `stopIfChanged` stops QEMU in
  switch-to-configuration's stop phase, before the sweep runs. The sweep
  therefore never unlinks an image QEMU still holds open. microvm.nix's own
  `restartTriggers` cover only the guest toplevel
  (`nixos-modules/host/default.nix:168`), which an image path doesn't change.
- **Live guests are never swept.** Before deleting, the sweep skips:
  - any image that some process holds open (a scan of `/proc/*/fd`, matched by
    device and inode, so a bind-mounted `/cache` path still matches);
  - any `gcroots/microvm-store/<name>/` whose guest is **absent from the
    configuration** and still running (`microvm@<name>` active).

  A guest removed from the config while still running (the `microvm@` template
  has `restartIfChanged = false`, so activation leaves it up) keeps its image
  and roots until it stops. The next boot, or the next change to the keep-set,
  finishes the cleanup (round 4). For a guest that is still configured, the
  keep-set alone decides. A guest with the feature turned off has no exporter,
  and restarts onto a fresh scratch store whose system closure the host roots,
  so its roots directory is removed even while it runs (round 5).

- A host rollback across an epoch bump makes the sweep delete the newer image.
  All of it is rebuildable (§4).

- **Periodic run.** A second oneshot, `microvm-store-sweep-periodic`, runs the
  same script on a daily timer, without `RemainAfterExit`. A guest that was
  removed while running, and has stopped since, is then cleaned up within a day,
  not at the next reboot (round 6).
- **A host that stops hosting guests.** If `virtualization.microvm-host` is
  dropped, the sweep goes with it. So `core.nix` emits, on every NixOS host
  where `microvm.host.enable` is false, `R /nix/var/nix/gcroots/microvm-store`
  (tmpfiles). A microvm guest (`microvm.guest.enable`) is excluded: it never
  holds the directory, and the line would change every guest's derivations,
  against I7 and test 10. No guest can still be running once the host module is
  gone, because its units vanish and switch-to-configuration stops them (round
  6). The images on `/cache/microvms` stay until the owner removes
  `/cache/microvms`, and §4 names this.

On a host without persistent guests, the cost is the sweep units, or the one
tmpfiles line. Test 10 names them.

### 2.5 Guest GC and space

The guest's `nix.gc` is on (core's `--delete-older-than 8d`; v0.1 forced it
off). The guest fragment sets `nix.gc.dates = mkForce "03:00"` (core sets
`05:00` at normal priority, so a `mkDefault` loses). That keeps the guest's GC
off the host's. The local-overlay GC deletes only upper paths, and it
invalidates dead rows, lower copies included (`deleteReferrersClosure` →
`invalidatePathChecked`).

A GC first syncs a row for every host store entry: 293 s and about 290k rows
(§2.1). The guest fragment sets `min-free = 8 GiB` and `max-free = 24 GiB`
(`mkForce`, guest only), so the daemon's auto-GC starts with far more room than
that growth needs. Test 14 measures the growth. `gc-reserved-space` is not used:
every new daemon connection reallocates the reserve, so the export's per-minute
connection would take it back during a GC (round 3).

### 2.6 Reconcile (guest)

`nix-store-reconcile.service` is a oneshot with `TimeoutStartSec=6h`. Its timer
has `OnBootSec=5min` and `OnUnitInactiveSec=15min`, and never starts a second
run while one is still going. Logins don't wait for it. The boot delay lets the
network come up, because core disables networkd's wait-online, which makes
`network-online.target` meaningless here.

No long work runs under the guest's GC lock. `verifyStore` holds `gc.lock`
shared for its whole run (`local-store.cc`). `--verify --repair` would therefore
block the daemon's own `min-free` auto-GC, and deadlock when a repair's
`addToStore` triggers it (round 4). The repair step runs separately.

Every Nix query below passes `--option narinfo-cache-negative-ttl 0`, so each
run asks the substituters afresh rather than reading the disk cache's one-hour
negative answer (round 5).

0. **Check the mount.** `/nix/store` must be an overlay whose `lowerdir` and
   `upperdir` end in `/nix/.ro-store` and `/nix/.rw-store/store`. If not, fail.
   This replaces `check-mount`.
1. **Scrub whiteouts.** Delete every top-level character-device entry in
   `/nix/.rw-store/store/` (a whiteout), skipping `.links`, and run the remount
   hook if any were deleted. A whiteout over a store path can appear when a
   guest GC deletes through the merged directory while the host has that
   directory but hasn't registered it yet (round 3). It would hide the host's
   copy for good.
2. **Find what is missing, by validity, not by file.**
   - **M** is the set of the database's rows (`nix path-info --all`) that are
     either:
     - in the upper layer, but have no file; or
     - not in the upper layer, and **invalid on the host**. This is a batched
       `nix path-info` against the lower store URL, over the same vsock socket.

     Both cases reduce to one test, which the implementation runs: a row with no
     upper entry that the host does not hold valid. An upper path whose file is
     lost has no upper entry, and the host never held it; an upper path whose
     file is lost while the host now holds the same path is served by the lower
     layer and is not missing. Validity is asked with
     `nix-store --store <lower> --check-validity --print-invalid`.

     Validity, not existence, decides. An interrupted host GC can leave a
     directory half-deleted after invalidating it. A file check would count that
     as present, and the guest would read a broken path silently (round 5).

   - **D** = M ∩ E, the missing paths the guest depends on (§2.3).
3. **Repair D by substitution only, references first.** Sort D topologically by
   references, leaves first. For each path run:

   ```
   timeout 1h nix-store --realise --repair <p>
   ```

   `p` is an opaque output path, so `Worker::makeGoal` creates only
   `makePathSubstitutionGoal(p, Repair)` (`worker.cc`). The build runs in the
   daemon through `buildPaths(bmRepair)`, which is trusted-only and so allowed
   for root. Nothing falls back to a build of the deriver.
   `nix-store --repair-path` would fall back: its `repairPath` runs in the
   client and builds the deriver in repair mode when substitution fails, and
   that re-substitutes every input's outputs into the upper layer before any
   `--max-jobs 0` check (round 6). That fallback is the duplication §1 removes.
   A repaired leaf is valid before its referrer is repaired. That ordering
   handles chains, because repairing B alone doesn't fetch a missing C whose
   stale row still reads as valid (round 4).

4. **Give up on what no substituter has.** A path in D still missing after step
   3 is **unsubstitutable** when every configured substituter that answers
   returns `null` from `nix path-info --json --store <s> <p>` with exit 0, and
   at least one public cache (`cache.nixos.org` or a cachix cache) is among
   those that answer. A LAN peer cache that is unreachable
   (`http://<host>:16893`, from `core.nix.remote-build-client`) counts as
   absent. It is a best-effort mirror of a store its host garbage-collects
   anyway, and a workstation that is switched off must not block the give-up
   forever (round 6). Measured on bitstream (2026-11-09): absent gives exit 0
   and `null`, and an unreachable cache gives exit 1. Any non-zero exit is a
   transport error and means "not known". A 403 counts as absent, because Nix
   doesn't distinguish it.

   This covers a local build as well: it is rebuildable by definition, and never
   repaired by a build here. The run counter for each path lives on the volume,
   in `/nix/var/nix/reconcile/<base>`. Guest restarts therefore don't reset it,
   and a deploy that restarts the guest can't keep postponing the give-up (round
   6). A run in which p is not unsubstitutable (present somewhere, or unknown)
   removes its counter, so the 3 runs are consecutive; a give-up that fails
   keeps it, so the next run retries the give-up. If p is unsubstitutable on 3
   consecutive runs, the guest gives up on it:
   - Remove **every** auto root whose `closure⁺` reaches p. That includes a
     `.drv` root that `keep-outputs` ties to p through a build input.
     `nix-store --query --roots p` lists these (it flips `computeFSClosure` with
     `keepOutputs`) by the user's link paths. Map those back to their
     `gcroots/auto/<hash>` entries and remove the entries. Such a root's own
     upper-only paths stay until a GC finds them dead, and nix-direnv rebuilds
     its profile on next use (round 6).
   - Run the guest's GC (`nix-store --gc`). Liveness decides what dies, so
     nothing still needed is deleted. A targeted `--delete` would refuse on any
     visited path outside its set, such as another `.drv` that uses the lost
     path's `.drv` as a build input (round 5).
   - Check that p is outside `closure⁺` of every remaining root, auto or not. If
     it isn't, a non-auto root (a profile generation, an open shell) still holds
     it. The run fails and names that root. The open-shell case clears when the
     shell exits, and `epoch` (§2.8) is the declarative last resort.

   nix-direnv sees its dead profile and rebuilds on the next `cd`.

5. **Drop stale rows.** Only when D is empty, run `nix-store --verify` (no
   repair). It holds the GC lock briefly and does no I/O beyond `stat`.
   `verifyPath` invalidates every missing row that has no valid referrer,
   recursing referrers first.

   Before the verify, if **M \ E has a member whose directory exists** (an
   `lstat` of `/nix/.ro-store/<base>`, the lower directly), which means a host
   path half-deleted by an interrupted host GC, the reconcile runs the guest's
   GC once. That member is dead in the guest, because it is outside E and R
   includes temp and runtime roots. The GC visits its directory, and
   `invalidatePathChecked` drops the row (`deleteStorePath` does nothing for a
   lower-only path). The verify alone would never catch it: it only checks
   existence, and the directory exists (round 6). The run fails if such a member
   survives the GC. The cost, a guest GC, is paid only in that rare case.

The run fails if:

- step 0 fails;
- a repair times out;
- D is non-empty at the end, for any reason other than a path still being
  counted toward its 3 runs;
- the final verify reports errors.

A failed oneshot stays `failed` until a run succeeds, so the existing
`NodeSystemdServiceFailed` alert keeps firing while the problem persists, except
across a reboot (§2.8). A stuck run hits `TimeoutStartSec` and becomes `failed`.

### 2.7 Invariants

- **I1:** every GC on the host (nightly, `min-free`, manual) reads the guest's
  last applied export as permanent roots, never a partial one (§2.4 step 4). The
  export is bounded by `maxExportPaths`.
- **I2:** each export contains every host path in the closure of the guest's
  roots and its upper paths at the time it was taken (§2.3).
- **I3:** every guest database row that is missing is resolved by a reconcile, 5
  minutes after boot and then every 15 minutes. A row is missing when it is in
  the upper layer with no file, or not in the upper layer and invalid on the
  host. Resolution is one of three outcomes:
  - a dependency is re-substituted;
  - an unsubstitutable dependency is given up after 3 fresh lookups. Its auto
    roots are removed, and the guest's GC deletes only what is then dead;
  - a stale row is dropped.

  Until then the unit fails and the existing alert fires.

- **I4:** the upper layer, the work directory and `/nix/var/nix` (database,
  gcroots, profiles, temproots, gc.lock) are on one volume. Build logs
  (`/nix/var/log`) stay on the tmpfs root and are lost at each restart, as
  today.
- **I5:** only the guest's daemon and the build hook it spawns
  (`nix __build-remote`, which receives the daemon's settings) open the
  local-overlay store. Every other client goes through the daemon, and so does
  every GC.
- **I6:** the vsock channel gives the guest no more than untrusted-daemon
  access, and the export is validated and capped. The guest's existing
  remote-build access to uplink, through its trusted `nix-remote-build` user, is
  unchanged (§2.2).
- **I7:** opt-in per guest. A guest without it evaluates to the same derivations
  as before. A microvm host without persistent guests gains exactly the sweep
  unit (test 10). No alert rule is added anywhere.

### 2.8 Interface and emission (den)

On the guest's host entity, in the guest schema (`virtualization/microvm.nix`,
beside `sharedNixStore` and `scratchVolumes`):

```nix
options.microvm.vsockCid = lib.mkOption {
  type = lib.types.nullOr (lib.types.ints.between 3 4294967294);
  default = null;
  description = "AF_VSOCK CID of this guest (unique on its host); emitted as microvm.vsock.cid.";
};
options.microvm.persistentStore = {
  enable = lib.mkEnableOption "a persistent local-overlay Nix store over the host's shared store";
  size = lib.mkOption {
    type = lib.types.ints.positive;
    default = 262144;
    description = "Ceiling in MiB of the store volume (sparse ext4 on the host's /cache).";
  };
  epoch = lib.mkOption {
    type = lib.types.ints.unsigned;
    default = 0;
    description = "Bump to discard the volume and start empty (recovery from a corrupt image).";
  };
  maxExportPaths = lib.mkOption {
    type = lib.types.ints.positive;
    default = 100000;
    description = "Most host paths the guest may pin; a larger export is refused whole.";
  };
};
```

**Size changes.** microvm.nix creates a volume only if its image doesn't exist
(`lib/volumes.nix`), so raising `size` would otherwise do nothing. The host
fragment adds an `ExecStartPre` on `microvm@<guest>`: when the image exists and
is smaller than `size`, `truncate -s '>'<size>M` on the image, then `e2fsck -fp`
and `resize2fs`; otherwise nothing, so a start pays no full fsck. That grows the
image and never shrinks it. Shrinking needs an `epoch` bump, and an assertion
can't see the old size, so the option's description says so (round 6).

**Emission.** Everything comes from `virtualization/microvm-guests.nix`, keyed
on `vm.microvm.persistentStore.enable` and `vm.microvm.vsockCid` from the
entity. It goes through a helper, `_persistent-store.nix` (the
`_gpu-passthrough-lib.nix` pattern), which returns the guest-side and host-side
fragments for one guest.

**Guest fragments,** merged into `microvm.vms.<guest>.config` the way shares,
volumes and the GC forces are today:

- `microvm.vsock.cid`;
- the volume, `writableStoreOverlay` and the `/nix/var/nix` bind with its initrd
  mkdir;
- `registerClosure = false`;
- `nix.settings.store = mkForce "daemon"`, the daemon's `NIX_USER_CONF_FILES`
  file and its `restartTriggers` (§2.1), plus the space settings (§2.5);
- the lower socket units (§2.2);
- the export and reconcile units, and the guest's `nix.gc.dates`.

In `microvm-guests.nix`, `persistentStore.enable` **overrides** a
`"/nix/.rw-store"` scratch entry: the entry is filtered out of `g.scratch`, and
the persistent volume takes its mount point. Turning the feature off brings back
exactly today's layout, writable store included (round 4). One local,
`hasRwStore = (any scratch volume is /nix/.rw-store) || persistentStore.enable`,
gates the following, which were all keyed on the scratch entry before:

- `writableStoreOverlay`;
- `nix.optimise.automatic = mkForce false`;
- `nix.settings.auto-optimise-store = mkForce false`.

Without that, core's `auto-optimise-store = true` trips microvm.nix's assertion
(round 3). The `scratchRoot` tmpfiles rule and its `impermanence.directPaths`
entry become conditional on `g.scratch != [ ] || persistentStore.enable`.
`nix.gc.automatic = mkForce false` becomes conditional on
`sharedNixStore && !persistentStore.enable`.

**Host fragments:**

- the vsock module and listener, and `Wants=`/`After=` on it from
  `microvm@<guest>` (§2.2);
- the image path in `microvm@<guest>`'s `restartTriggers` (§2.4);
- the import units and the `nix-gc` ordering.

The sweep is emitted for every microvm host.

**Assertions,** all computed over `host.guests` entities, with no read of an
evaluated guest:

- `persistentStore.enable` requires `sharedNixStore` and `vsockCid != null`;
- each `vsockCid` is unique among the host's guests;
- `/cache` must be among the host's `stateVolumes`;
- the host-wide `system-owner` rule (§2.2).

**Paths** come from the existing helpers only (`stateDir`, `scratchRoot`,
`rwStore`). No host file names a path.

**Alerting** needs no new rule. The kube-prometheus-stack mixin already fires
`NodeSystemdServiceFailed` on every failed unit on every scraped host. The rule
is `node_systemd_unit_state{job="node-exporter",state="failed"} == 1` with
`for: 5m`, rendered in
`generated/manifests/prod-axon/kube-prometheus-stack/PrometheusRule-kube-prometheus-stack-node-exporter.yaml`.
The guest's node-exporter runs the `systemd` collector, and alloy remote-writes
it with `job = node-exporter` and `instance = uplink-dev`. The pass/fail state
of each timer-driven unit (export, import, reconcile, periodic sweep) lives in a
separate oneshot, `<unit>-verdict.service`. Each work unit's `OnFailure=` starts
it, and it exits 1, so it stays `failed`; its `OnSuccess=` starts
`<unit>-verdict-clear.service`, which runs `systemctl reset-failed` on the
verdict. An instance keeps its instance: `microvm-store-roots-verdict@<guest>`.
So a retry that is still running (`activating`) never clears the failure, and
the alert stays on until a run succeeds (round 6). A reboot still resets the
failed state, and the alert then fires again within the first run plus
`for: 5m`. That gap is accepted.

`hosts/uplink-dev.nix` sets, on its entity, `microvm.vsockCid = 3` and
`microvm.persistentStore.enable = true`. Its `/nix/.rw-store` scratch entry
stays, and is overridden while the feature is on. It keeps its impermanence
assertion: persisting `/nix` through impermanence is still wrong. Its comment
points here.

### 2.9 Rollout

Two commits, deployed in order:

1. **The sweep alone,** on every microvm host, with an empty keep-set beyond
   today's scratch images. Every later generation, and every rollback target
   after this one, then carries a sweep that cleans up whatever a newer
   generation left behind.
2. **The feature,** enabled on uplink-dev.
3. **State on zvols (§2.10),** with uplink-dev selecting `zvol`. The first
   start after deploy migrates its state: 16 GiB plus 372 MiB, about 2.17M
   inodes. That deploy is planned at an owner or agent checkpoint.

A rollback to before commit 1 is the only way to leave `gcroots/microvm-store/`
and the image behind, and §4 names it (round 4).

### 2.10 Guest state on block volumes

**Why.** A guest's `/persist` and `/cache` are virtiofs shares of host
directories. `--inode-file-handles=never` is required there, because ZFS
answers `open_by_handle_at` on an open-but-unlinked file with ESTALE, which
breaks `br` (see `microvm-guests.nix`). In that mode virtiofsd holds one O_PATH
fd for every inode the guest kernel has cached. Measured on 2026-11-10:

- The den-ag-design checkout alone is about 700k inodes, mostly
  `reports/*.probes`, and one walk of it pins about 700k fds.
- 1,441,676 fds were held after one morning's runs.
- Each held fd pins about 2.9 KB of unreclaimable host kernel memory: znode
  1008 B, dnode 904 B, dbuf 352 B, SA 248 B, file 192 B, dentry 192 B
  (`/proc/slabinfo` on uplink). That is about 4 GiB at 1.44M.
- The limit was raised to 4,194,304. Parallel worktrees pass it, which makes
  ENFILE for the whole guest the failure mode. That happened twice on
  2026-11-10, before the raise.

No limit is both safe and sufficient, and dropping caches on a timer only treats
the symptom. The fix is to stop serving the guest's state through virtiofs.

**Shape.** Opt-in per guest, as a typed entity option beside `scratchVolumes`:

```nix
options.microvm.stateBackend = lib.mkOption {
  type = lib.types.enum [ "virtiofs" "zvol" ];
  default = "virtiofs";
  description = "How the guest's /persist and /cache reach it: host directories over virtiofs, or a ZFS zvol per volume, mounted as ext4 in the guest.";
};
options.microvm.stateVolumeSizes = lib.mkOption {
  type = lib.types.attrsOf lib.types.ints.positive;
  default = { "/persist" = 262144; "/cache" = 131072; };   # MiB, sparse; measured use 16 GiB / 372 MiB
  description = "zvol size per state volume (stateBackend = zvol). Grow-only; a grow applies at the next guest start.";
};
options.microvm.dropPreZvolBackup = lib.mkEnableOption "deleting this guest's pre-zvol backup of its old state directories";
```

**The parent dataset.** `zvolParent` is a `virtualization.microvm-host` setting.
On a host with `disk.zfs-disk-single` it defaults to `zroot/local/microvms`, the
same pattern `core/impermanence/zfs.nix` uses. An assertion requires it whenever
a guest selects `zvol`. disko never adds datasets to an existing pool, so the
volumes unit creates the parent itself:
`zfs create -p -o canmount=off -o mountpoint=none <parent>` (round 7).

A second host setting, `destroyStateZvols` (a list of zvol names, empty by
default), is how a zvol nobody uses any more gets destroyed (Leaked zvols,
below).

**Who opts in.** uplink-dev selects `zvol`. cortex-cuda keeps `virtiofs`, and
its derivations don't change (I7, test 10). The exchange share is gated on
`persistentStore.enable`, and cortex-cuda doesn't have that either.

**Host units.** There are two oneshots per zvol guest, each with
`requiredBy` and `before` `microvm@<guest>`, `restartIfChanged = false` and
`RemainAfterExit = no`. So they run again at every guest start, and a switch
never restarts them. A switch that restarted them would take the running guest
down, which is the trap `zfs-disk-single.nix` documents (round 7). Both run as
root.

- **`microvm-state-volumes@<guest>`** has `After=zfs-import-zroot.service
  zfs-volumes.target`. For each state volume it does the following, and every
  step either completes or fails loudly:
  1. Create the parent if absent (above).
  2. **Create, and format only in the same run.** If
     `<parent>/<guest>-<name>` is absent:
     - `zfs create -s -V <size>M -o volmode=dev -o volblocksize=16K -o com.sun:auto-snapshot=true`.
       - `com.sun:auto-snapshot=true`, because the zvol would otherwise inherit
         `false` from `zroot`. Today the state lives in `local/persist` and
         `local/cache`, which are `true`, so a snapshot service would otherwise
         skip it (round 7).
       - `volmode=dev` only hides partitions inside the zvol from the host. It
         doesn't stop a host mount.
     - Wait for `/dev/zvol/<…>` (`udevadm settle`, then a 60 s bounded wait for
       the link).
     - Require `blkid -p` to report no signature at all.
     - Run `mkfs.ext4 -E nodiscard`.
     - Then `zfs set json64:formatted=1`.

     The `zfs create` itself sets `-o json64:formatted=pending`, and the property
     becomes `1` only after `mkfs` succeeds. A run that finds `pending` waits for
     the link and runs `mkfs.ext4 -F` without probing, whatever an interrupted
     earlier `mkfs` left behind (round 9). Nothing has ever opened
     such a volume, because `microvm@` requires this unit to succeed. A crash or
     timeout between `create` and `mkfs` therefore recovers by itself (round 8).
     An existing zvol whose `json64:formatted` is absent or holds any other value
     makes the unit fail, and it is never formatted. A probe failure, a device
     that isn't ready, or a partition table can't lead to a format (round 7).
  3. **Grow only.** If the declared size is larger than `volsize`,
     `zfs set volsize`. If it is smaller, fail and change nothing.
- **`microvm-state-migrate@<guest>`** has `After=microvm-state-volumes@<guest>`,
  `TimeoutStartSec=infinity` and `PrivateMounts=yes`, so a killed unit can't
  leave a mount in the host namespace. **The migration is one-way.** It keys on
  what it finds on disk, so a crash at any point resumes, and `stateDir` is never
  a live directory or a missing path after migration starts (round 10):
  - **Nothing at all** (`stateDir` and `.pre-zvol` both absent: a guest whose
    first backend is zvol). It writes the tombstone and sets `json64:migrated`,
    with nothing to copy (round 10).
  - **`stateDir` is a directory.** The run then works in these steps:
    1. Run `udevadm settle`, then refuse if anything holds the zvol open
       (`fuser -s /dev/zdN`). Udev's `watch` probe holds it briefly after `mkfs`
       (round 9).
    2. Write the tombstone to a temporary file beside `stateDir` (with fsync),
       then atomically swap the two with `renameat2(RENAME_EXCHANGE)`
       (`mv --exchange`). At that point `stateDir` is the tombstone and the
       temporary name holds the directory.
    3. Rename the temporary name to `<stateDir>.pre-zvol`.

    From step 2 on, `stateDir` is always the tombstone, never missing and never
    empty, even across a crash.
  - **`stateDir` is the tombstone, and `json64:migrated` is absent.** Copy:
    1. Mount the zvol, then run
       `rsync -aHAXS --numeric-ids --delete <stateDir>.pre-zvol/ <mnt>/`. No
       guest has opened the zvol yet (`microvm@` requires this unit), so
       `--delete` only clears an interrupted earlier copy.
    2. Unmount, then `zfs set json64:migrated=<ISO time>`.
  - **`json64:migrated` set:** nothing to do.

  After that, the zvol is the only copy kept current. Nothing ever syncs from
  the directory again (round 9).

- **`microvm-state-guard@<guest>`** is emitted for every guest whose
  `persistentStore.enable` is true, whatever its backend. It is a oneshot,
  `requiredBy` and `before` `microvm-virtiofsd@<guest>`, and
  `restartIfChanged = false`. On the virtiofs backend it fails, and stays
  `failed`, when `stateDir` is not a directory. Its message is the tombstone's
  text, `migrated to <zvol> at <time>`. The fleet's `NodeSystemdServiceFailed`
  alert then names the refused rollback. Without the guard, the refusal shows up
  only as virtiofsd looping in `activating`, which no failed-unit alert sees
  (round 10, measured: tmpfiles `d` on a file logs and exits 0, and virtiofsd 1.14
  exits 1 on `ChdirNewRoot(NotADirectory)`). Gating on `persistentStore.enable`
  leaves cortex-cuda unchanged.

**The disks.** The guest gets them as `microvm.volumes` entries with
`image = "/dev/zvol/<…>"`, `autoCreate = false`, `mountPoint = null`,
`fsType = "ext4"`, a `serial` of `<name>`, and `direct = true`.

- `mountPoint = null`. Otherwise microvm.nix emits its own `/dev/vd<letter>`
  fileSystems entry, which conflicts with the one below (`mounts.nix:104`).
- `direct = true` (O_DIRECT, `cache=none`), so the host page cache doesn't hold
  the guest's data. ARC keeps `primarycache=all`: it is reclaimable, unlike the
  pinned fds. `primarycache=metadata` with `volblocksize=16K` would turn 4K
  guest writes into uncached read-modify-writes (round 7).
- The qemu runner passes `discard=unmap`, so guest TRIM frees pool blocks.

**What a zvol guest drops:**
- its `/persist` and `/cache` virtiofs shares (`stateShares`);
- its tmpfiles `stateDir` rules.

For a zvol guest, `impermanence.directPaths` lists `stateDir` (the tombstone)
and `<stateDir>.pre-zvol` (the backup), the latter until `dropPreZvolBackup` is
set. So persist-orphans doesn't report either as an orphan and invite a manual
delete (round 10).

**The persistent store's own image** stays an ext4 image file on the host's
`/cache` dataset (§2.1).

**Guest.**
- `fileSystems."/persist"` and `fileSystems."/cache"` are
  `device = "/dev/disk/by-id/virtio-<serial>"`, ext4, `neededForBoot`,
  `autoResize = true`. That's nixpkgs' `x-systemd.growfs`, an online ext4 grow
  at mount. The by-id path replaces a label, because ext4 labels hold 16 bytes
  and `uplink-dev-persist` is 18 (round 7). An assertion checks that each serial
  is at most 20 bytes. Impermanence binds from them exactly as before.
- TRIM comes from nixpkgs' default `services.fstrim` (weekly). No `discard`
  mount option.

**Migration size.** Measured on uplink on 2026-11-10: `/persist/microvms/uplink-dev`
is 16 GiB on disk (32 GiB apparent), and `/cache/microvms/uplink-dev` is 372 MiB.
That's 2,170,125 inodes in total. The scratch images sit beside the state
directories, not inside them, so they are never copied. The copy runs in the
start phase of the deploy that switches the backend: `restartIfChanged` makes
that deploy restart the guest. So that deploy is planned at a checkpoint, and it
runs for as long as the copy takes. Test 18 records the time.

**The backup.** `<stateDir>.pre-zvol` stays until the owner sets
`dropPreZvolBackup = true`. The sweep then deletes exactly those two named paths
for that guest, never a glob, and only when the guest's backend is `zvol` and
both zvols have `json64:migrated`. The owner flips that option, so dropping the
backup is a config change, not a runbook.

**Leaked zvols.** A zvol whose guest is gone is never destroyed implicitly. Destroying ZFS data is irreversible, and the zvol is
the only current copy. The sweep lists zvols under `zvolParent` that belong to
no configured zvol guest, and fails its verdict while any exist, so the fleet's
failed-unit alert names them. The remedy is declarative: add the name to the
host's `destroyStateZvols`. The sweep then destroys a listed zvol only if its
name matches **no configured guest under any backend** and `fuser` shows it idle
(round 9).

A configured guest on `virtiofs` that owns a zvol with `json64:migrated` is a
refused rollback, not a leak. Its guard fails (above), and its zvol is never
counted as leaked or destroyable. A refused rollback can therefore never lead
the owner to destroy the only current copy (round 10).

**Rollback is not supported after migration.** It fails loudly instead:
- Setting `stateBackend` back to `virtiofs` fails the guest's start. The
  guard unit fails on the tombstone and names it.
- Rolling the host back to a generation older than §2.10 also fails to start
  the guest. That generation has no guard, though, so the only signals are
  virtiofsd's `ChdirNewRoot … NotADirectory` in the journal and the fleet's
  `HostSilent` for the guest (round 10).

So a guest never boots onto stale or empty state, and nothing it writes ever
diverges between two copies. To actually return a guest to virtiofs, the state
has to be copied back out of the zvol. That is a non-goal, and §4 states it. A
**host rollback is fine** as long as the target generation also runs this guest
on `zvol`: every commit-3+ generation does.

**Capacity.** The zvols are sparse, so their sizes can overcommit the pool. A
full pool reaches QEMU as a block write error, and QEMU's default `werror`
pauses the whole VM, which only `HostSilent` would report (round 9; whether a
zvol answers ENOSPC or EIO is UNVERIFIED). So the defaults are sized from
measured use plus headroom (256 GiB and 128 GiB, against 16 GiB and 372 MiB
used), grow-only. §4 names the overcommit, and test 21 measures it.

**Snapshots and per-file access.** The zvols carry
`com.sun:auto-snapshot=true`, the same as the datasets they replace. They share
the host's still-missing snapshot service. Per-file restore means cloning a
snapshot and mounting it read-only on the host. That is a manual inspection
path, and a non-goal for automation here.

**Effect on the rest of this spec.**
- §2.3/§2.4 export through the exchange share for every persistent-store guest.
- `--rlimit-nofile=4194304` and `--inode-file-handles=never` remain only on
  virtiofs-backend state shares and the exchange share.
- ESTALE can't arise on zvol state: the guest's filesystem is native ext4.

## 3. Acceptance (measured, on uplink-dev unless noted)

Each test has a control that must FAIL without the mechanism. A control that
passes means the test proves nothing.

1. **Survives a restart, from empty.** Start with a fresh image (`epoch` bumped)
   and check that boot completes and the initrd mkdir ran. Then load the
   den-ag-design devshell (`cd`), restart uplink-dev, and `cd` again. direnv
   must load with no build and no fetch lines. Control: today's layout rebuilds.
2. **No duplication.** After test 1, the number of upper paths that also exist
   in `/nix/.ro-store` must be 0. Control: today's measured 1024 of 4879. Record
   `du` of `store/`.
3. **Every host GC kind honours the roots.** On the host, build a small path
   with no out-link. In the guest, build a path that references it, and wait for
   the import. Then run, one at a time, `nix-gc.service`, `nix-collect-garbage`,
   and `nix-store --gc --max-freed 1G` (the `collectGarbage` path that
   `min-free` takes). The path must survive each. Control: the same with the
   import masked deletes the path, and "nothing deleted" counts as a FAIL. Test
   6 uses that deletion.
4. **The import never applies during a GC.** Start a long host GC and trigger an
   import. The import must wait, apply its set only after the GC ends, and never
   fail. Run two GCs back to back with a new dependency exported during the
   first: the second must see it. Then run two `nix-gc` starts with no reboot
   between them, and confirm the import re-ran before each.
5. **Strict, capped import.** Each case must fail the unit within its timeout
   and leave the previous root set unchanged:
   - a non-store line;
   - `roots` as a FIFO (it must not hang);
   - `roots` as a symlink to `/etc/shadow`;
   - the exchange directory's `store-roots` as a hard link to a file outside it
     (the guest can't make one: the share's root is the exchange directory);
   - `maxExportPaths + 1` valid lines.

   A path that doesn't exist on the host is skipped and counted.

6. **Reconcile.** Starting from test 3's control (the host deleted a guest
   dependency):
   - A substitutable dependency is repaired. So is a local build with a valid
     deriver.
   - A **depth-2 chain** (upper A → lower B → lower C, with B and C deleted on
     the host) is repaired in a single run.
   - With substituters blocked, the run fails, deletes nothing, keeps failing
     and keeps the alert on, and a later run repairs the path. The alert must
     not resolve while a retry is activating.
   - An **unsubstitutable** dependency (a host-only build, absent from every
     substituter) is given up on its third run. Its nix-direnv root is removed,
     the guest GC deletes what is then dead, and the next `cd` rebuilds.
     - Repeat with another root's `.drv` that uses it as a build input. That
       root is removed too, and the give-up completes.
     - Repeat with bitstream's cache blocked. The give-up still completes.
     - Repeat with a guest restart between runs 2 and 3. The give-up still
       happens on run 3.
   - A local build with a valid deriver is **not** rebuilt by the reconcile. The
     repair fails without a build, and the number of upper entries is the same
     before and after.
   - A transient 404 that clears within 30 minutes does not trigger a give-up
     (fresh lookups, negative TTL 0).
   - **Half-deleted host path:** interrupt a host GC mid-delete, so the
     directory is present but invalid. If the path is in E, step 2 puts it in M
     and it is repaired. If it is outside E, step 5's single guest GC drops it
     and the verify succeeds. The control: with that GC removed, the run must
     report the member and fail, not succeed.
   - A repair with free space under `min-free`: the auto-GC runs and the repair
     completes, with no deadlock.
   - Plant a whiteout over a lower path in `store/`: step 1 removes it, and the
     path is visible again.
   - A stale row with no referrers is dropped.
   - **Stale-dentry control:** delete a lower path on the host right after the
     guest stat'ed it, then check that M finds it. If M doesn't, a targeted
     cache drop is added to step 2 before merge.

   Afterwards `nix-store --verify` is clean.

7. **Inflation doesn't reach the host.** In the guest, run
   `nix-store --gc --print-live`, then a `--dry-run` GC. The next export's line
   count must stay within 1% of the one before, and the root directory's count
   must not move. Then run a real guest GC and check:
   - the export didn't grow;
   - the host store's path count is unchanged;
   - the upper layer holds no whiteouts outside `store/.links`
     (`find store -path store/.links -prune -o -type c -print`, count 0). Record
     the count inside it (see §4).

   Record the GC's duration.

8. **One store entry point.** `sudo nix store info` must report `daemon`, and
   `sudo nix-collect-garbage` must run the overlay GC inside the daemon, which
   the daemon journal shows.
9. **Sweep on the last guest, and epoch.** Bump `epoch` on uplink-dev and
   deploy: the guest restarts before the sweep runs, the old image is gone, and
   `lsof` on the host shows no deleted image still held open. Then set
   `persistentStore.enable = false` (uplink's only persistent guest) and deploy.
   After activation, with the guest running again:
   - `gcroots/microvm-store/uplink-dev/` is gone;
   - the image is gone;
   - the guest's store is writable again (today's scratch layout).

   Repeat with a rollback from commit 2 to commit 1 (§2.9). Then remove a test
   guest while it runs, and stop it: the periodic sweep cleans up within a day,
   with no reboot. Finally, remove a test guest from the config while it is
   running: its image and roots survive until it stops.

10. **Defaults unchanged.** Compare before and after:
    - cortex-cuda's `system.build.toplevel.drvPath` and
      `microvm.declaredRunner.drvPath`: equal.
    - cortex's toplevel, with `nix-diff` (or `nix store diff-closures`) over the
      whole derivation, not the unit names. The only differences allowed are the
      sweep units and their scripts.
    - a host without `microvm-host` (bitstream): only the tmpfiles line.
    - uplink: only the units named in §2 (round 6).
11. **Restore.** Swap in a copy of the volume taken before a host GC that
    deleted some of its paths, and boot. The first reconcile (5 minutes after
    boot) must repair or drop every row whose file is missing, and builds after
    it must hit no ENOENT.
12. **Host daemon restart.** Restart uplink's `nix-daemon` during a guest build.
    The build must fail loudly, the next one must succeed, and
    `nix-store --verify` must be clean.
13. **Export cost and size.** Record the export's duration and the size of E
    with the devshell loaded, and again after a multi-host nix-config evaluation
    in the guest. The run must fit well inside its 1-minute period, and E must
    stay under `maxExportPaths`. If either fails, the period or the cap changes
    before merge.
14. **Full volume, and build dirs.** Kill a guest build mid-way and reboot:
    `/nix/var/nix/builds` is empty. Then switch the guest in place during a
    build: the build survives. Raise `size` and restart the guest: the
    filesystem has grown. **Full volume.** Fill `store/` to within `min-free` of
    the volume's size. The daemon's auto-GC must start (journal) and complete,
    no write may fail with `SQLITE_FULL`, and the database's growth during the
    GC is recorded.
15. **Host temp directories.** Plant `/nix/store/tmp-test` on the host and run a
    guest GC. The GC must complete (see §4).
16. **No fd growth.** With uplink-dev on zvol state, walk the den-ag-design tree
    (`git status`) three times, then add one worktree. The guest's virtiofsd fd
    count must stay under 10,000: only the exchange share and the host-key share
    hold any. Control: the same walk on today's virtiofs `/persist` adds about
    700k.
17. **Performance A/B.** On the same uplink-dev, time `git status`,
    `git worktree add` and one guarded CI family run in the den-ag-design repo:
    first on virtiofs `/persist` (before commit 3), then on the zvol. Record both.
    The zvol must not be slower on any of them.
18. **Migration.** Starting from today's directories, the first start after
    commit 3 must:
    - copy `/persist` and `/cache`, giving equal file counts, a sampled
      `sha256sum` match and preserved xattrs;
    - set `json64:migrated`;
    - leave `<stateDir>.pre-zvol` and a tombstone file at `stateDir`;
    - boot the guest with every impermanence bind present.

    Record the copy time.
    - A second start copies nothing and boots.
    - **Never reformat:** clear `json64:formatted` on a volume and start. The
      unit fails, and a planted marker file survives.
    - **Interrupted format:** kill the unit after `zfs create` and again after
      `mkfs` (`formatted=pending` both times). The next start completes it and
      the guest boots.
    - **Busy refusal:** on a throwaway guest with QEMU up, clear
      `json64:migrated` and start the migrate unit by hand. It refuses, and the
      zvol, the tombstone and `.pre-zvol` are all unchanged. Straight after a
      format, it doesn't refuse (`udevadm settle`).
    - **Crash points:** kill the migrate unit after the swap, after the rename to
      `.pre-zvol`, and partway through the rsync. Each time, `stateDir` is the
      tombstone, and the next start completes the copy from `.pre-zvol`.
    - **zvol first:** a new guest on `zvol` with no `stateDir` boots, and its
      zvol gets `json64:migrated`.
    - **Rollback refused:**
      - Set `virtiofs`: `microvm-state-guard@uplink-dev` is `failed`, its message
        is the tombstone's, and the failed-unit alert fires.
      - Separately, roll the host back to the commit-2 generation: the guest
        doesn't start, the journal shows `NotADirectory`, and `HostSilent` fires. Return to `zvol` or the current generation, and the guest boots
      with the writes it made before the rollback.
    - **Backup drop:** set `dropPreZvolBackup`. Only that guest's two
      `.pre-zvol` paths go.
    - **Leaked zvol:** create a zvol under the parent for no guest. The sweep's
      verdict fails and names it. Add it to `destroyStateZvols`, and it's
      destroyed. A listed zvol that is still open, or whose name matches any
      configured guest, is left alone. That includes a guest set back to
      `virtiofs`, whose zvol survives with `destroyStateZvols` listing it.
19. **Grow.** Raise `stateVolumeSizes."/persist"` and deploy. The running guest
    is not restarted, so nothing changes yet. At its next start, `volsize` grows
    and the guest's `df` shows the larger filesystem. A smaller value fails the
    volumes unit at the next start, and the volume stays unchanged.
21. **Overcommit.** On a throwaway pool, fill it under a running test guest with a
    zvol volume. Record whether the guest pauses (`werror`) or sees errors, and
    that `HostSilent` or the failed-unit alert fires.
20. **ESTALE gone.** Run `br`'s anonymous-temp-file pattern on `/persist`
    (create, unlink, then fstat and pread): it succeeds on zvol state. Control:
    the same pattern fails on a virtiofs share with `--inode-file-handles=prefer`.

## 4. Risks and limits

- **The window.** A host GC can delete a host path that the guest started
  depending on too recently. That is either less than one export period (1
  minute, plus the import's latency) before the GC took its lock, or while a GC
  was already running: the import waits on the lock, and that GC read its roots
  at the start. That requires a path the host doesn't root itself, which means
  host garbage the guest happened to pick up. The next reconcile repairs it or
  invalidates the paths built on it (I3), so the failure is loud and bounded.
  Closing the window completely needs an upstream change: local-overlay adding a
  lower temp root before it trusts a lower path. That is not attempted here.
- **Experimental feature.** `local-overlay-store` is experimental in Nix 2.34.9.
  A Nix bump re-runs tests 1–8.
- **OverlayFS lower changes.** The kernel's OverlayFS documentation forbids
  changing a mounted lower layer, and the host GC does exactly that. This is
  today's behaviour: uplink-dev has run with the host collecting under it
  nightly since 2026-11-05. The paths the host deletes are ones the guest holds
  no roots for. Stale lookups are why step 1 reads the lower directly.
- **The link farm.** After deleting, `collectGarbage` unlinks files in
  `/nix/store/.links` that have a link count of 1, using `unlink()`, not the
  overlay's `deleteStorePath`. The guest's merged `.links` is the host's, so a
  guest GC whites out the host's orphaned link-farm files in the guest's view.
  The guest never reads `.links` (microvm.nix asserts `auto-optimise-store` off
  with a writable overlay), so this stays confined there. Test 7 counts it.
- **A host `tmp-*` directory can abort a guest GC.** The guest's GC sees the
  host's in-progress `tmp-XXXX` directories through the merged view. If virtiofs
  keeps `flock` local to the guest, the GC passes such a name to the overlay's
  `deleteStorePath`, whose `StorePath{}` constructor throws, and the GC aborts
  (round 3, source reading, UNVERIFIED on a live guest). The abort is transient:
  the host's own GC removes stale `tmp-*` directories, and the next guest GC
  succeeds. Test 15 measures it. If it reproduces, it is reported upstream with
  the one-line guard (`maybeParseStorePath`), and the guest's Nix does not carry
  a local patch.
- **Guest GC cost.** Each guest GC takes about 290k daemon queries (293 s on the
  probe) and the database growth §2.5 reserves room for.
- **Host daemon dependency.** The guest's Nix works only while the host's daemon
  answers. A host deploy that restarts the daemon causes transient guest errors
  (test 12).
- **No rollback after migration** (§2.10). A zvol guest set back to
  `virtiofs`, or a host rolled back to before commit 3, refuses to start it.
  Going back needs a copy out of the zvol, which is a non-goal. The
  `.pre-zvol` backup holds the state as of migration.
- **Sparse overcommit** (§2.10, Capacity). A full pool pauses the guest.
- **The host loses per-file visibility** of a zvol guest's state. Inspection
  goes through a snapshot clone.
- **zvols are destroyed only when named in `destroyStateZvols`** (§2.10). Until
  then, a leaked one keeps alerting.
- **ARC caches zvol data** (`primarycache=all`). With `direct = true`, the host
  page cache doesn't also hold it. Under memory pressure, ARC gives memory back.
- **Images after a host stops hosting guests** (§2.4) stay on `/cache/microvms`.
  They hold rebuildable data only, and nothing pins host paths through them.
- **Rollback before the sweep's commit** (§2.9) leaves the roots and the image
  in place until the sweep comes back. Disk only; nothing is corrupted.
- **Disk.** Bounded by `size` and the guest's GC and auto-GC. Turning the
  feature off, or bumping `epoch`, deletes the image through the sweep. Its
  contents are all rebuildable.
- **Root count.** One host symlink per exported path, at most `maxExportPaths`.

## 5. Alternatives rejected

- **v0.1: a plain local store with a persisted database.** It duplicates
  (measured 1024 of 4879), leaves whiteouts, keeps old system closures valid
  after the host deletes them, and needs GC ordering that `min-free` and manual
  GCs bypass.
- **v0.2's export of the database's lower rows.** A dry-run or partial guest GC
  inflates the rows to nearly the whole host store, and a lower path can be used
  with no row at all (round 2).
- **A temp-root keeper** (a guest process holding the host daemon's temp roots).
  It is native for a GC already running. But temp roots die with the connection,
  so a stopped guest loses its protection.
- **The host's daemon as the guest's only store.** Indirect roots register guest
  paths that don't exist on the host, so the host's GC drops them as stale. The
  guest's runtime roots are also invisible to the host's `/proc` scan.
- **Sharing the host database read-only over virtiofs:** wrong answers while it
  changes (§2.2).
- **A full guest store** (`storeOnDisk`, or a persistent `/nix`): replicates the
  largest part of the disk.
- **Fast refetch only:** makes the loss cheaper. It doesn't remove it.

## 6. Non-goals

- Deduplicating upper copies of paths the host acquires later. The guest GC
  reclaims them once they are dead.
- Multi-tenant guests (§2.2's `system-owner` rule refuses them).
- Persistence for guests without `sharedNixStore`.

## 7. Open measurements

Tests 7, 13 and 14 carry numbers this design depends on but couldn't measure
without the implementation: E's size and export time, and the guest GC's
database growth on a full volume. If any of them falls outside its stated bound,
the corresponding period or reserve changes before merge.

## 8. Review history

**Round 1 (v0.1): 17 surviving objections.**

| v0.1 objection                                   | Resolution                                                       |
| ------------------------------------------------ | ---------------------------------------------------------------- |
| `min-free` and manual GCs bypass the ordering    | permanent roots read by every GC kind (I1, test 3)               |
| lower paths refetched into the upper layer       | local-overlay (§2.1, test 2)                                     |
| database keeps deleted paths valid               | no `registerClosure`; guest GC; reconcile (§2.6, tests 6 and 11) |
| whiteouts persist                                | local-overlay deletes through the upper layer (test 7)           |
| export misses runtime and temp roots and outputs | `--print-roots` plus `--include-outputs` (§2.3)                  |
| path unit misses nix-direnv refreshes            | a 1-minute export; the window is priced (§4)                     |
| import during a running GC                       | shared host GC lock (§2.4, test 4)                               |
| `RemainAfterExit`                                | pinned to `no` (test 4)                                          |
| guest-written timestamp                          | host-side mtime, alert only (§2.4)                               |
| hung guest blocks GC                             | no GC refusal; last set kept (§2.4)                              |
| FIFO, symlink, size, TOCTOU                      | single-fd `O_NOFOLLOW                                            | O_NONBLOCK`, `S_ISREG`, count cap (test 5) |
| `rename` over a directory                        | add-then-remove under the lock (§2.4)                            |
| removed guest keeps roots                        | sweep (test 9)                                                   |
| unbounded upper layer                            | guest GC and auto-GC (§2.5)                                      |
| bind runs too late                               | `neededForBoot` plus an initrd mkdir (§2.1)                      |
| emission scattered                               | one helper and the existing path helpers (§2.8)                  |
| acceptance 6 not a measure                       | drvPath equality (test 10)                                       |

**Round 2 (v0.2): 16 surviving objections** (18 raised; two raised by two
critics each).

| v0.2 objection                                                              | Resolution                                                                        |
| --------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| export inflated by a dry-run or partial GC; a guest can pin the whole store | E from roots and upper closure (§2.3); `maxExportPaths` cap (§2.4, tests 5 and 7) |
| a lower path used without a row is unexported                               | `--print-roots` covers root targets (§2.3)                                        |
| boot reconcile deletes repairable paths when offline                        | `network-online`; delete only on a positive miss (§2.6, test 6)                   |
| `--delete` aborts on temp-rooted referrers                                  | one path at a time, topological, retry (§2.6 step 3)                              |
| reconcile deadlocks on its own shared lock                                  | the export takes no lock (§2.3)                                                   |
| missing-check reads the overlay's dentry cache                              | `lstat` on the lower directly (§2.6 step 1)                                       |
| "before login" is only an ordering; host listener unordered                 | stated as ordering, alerting (§2.6); `microvm@` `Requires=` the listener (§2.2)   |
| full volume wedges the GC                                                   | `gc-reserved-space`, `min-free`/`max-free`; `nix-gc` alerted (§2.5)               |
| off and recovery are runbooks                                               | sweep deletes images; `epoch` (§2.4, §2.8, tests 1 and 9)                         |
| alert clears itself                                                         | counters plus `keep_firing_for` (§2.8, test 6)                                    |
| `check-mount` fails under the systemd initrd                                | `check-mount=false`; the reconcile checks the mount (§2.1, §2.6)                  |
| `%` in `Environment=`                                                       | the store URL lives in a daemon-only `nix.conf` (§2.1)                            |
| fresh volume: bind source missing                                           | initrd mkdir unit (§2.1, test 1)                                                  |
| the guest GC schedule loses to core                                         | moot: the export doesn't depend on the guest GC (§2.5)                            |
| option set in the guest's `nixos` block; cid read from an evaluated guest   | both are entity options (§2.8)                                                    |
| sweep vanishes with the last guest; test 10 blind to the host               | sweep on every microvm host; test 10 diffs cortex (§2.4, test 10)                 |

**Round 3 (v0.3): 17 surviving objections** (19 raised). The count was flat, and
most were fix-induced, so v0.4 cuts machinery.

| v0.3 objection                                                                          | Resolution                                                                                 |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `--delete --ignore-liveness` refused by the daemon; a rooted lost path can't be deleted | reconcile is Nix's `--verify --repair` (`invalidatePath`, `repairPath`); no deletes (§2.6) |
| cache row undeletable while the host holds its deriver                                  | `verifyPath` invalidates directly, not through the GC (§2.6)                               |
| repair outcomes undefined; 403 counted as absent                                        | a failed repair is only a failure, never a deletion (§2.6 step 4)                          |
| whiteouts from GC overlap, invisible to the reconcile                                   | whiteout scrub plus remount (§2.6 step 1); guest GC at 03:00 (§2.5)                        |
| `gc-reserved-space` reallocated mid-GC                                                  | dropped; `min-free` headroom (§2.5, test 14)                                               |
| host `tmp-*` aborts the guest GC                                                        | transient, bounded by the host GC; test 15; upstream report (§4)                           |
| E can exceed the cap after evaluations                                                  | no `--include-outputs` on U; roots first; truncation alerts (§2.3, test 13)                |
| `network-online` reached without the network                                            | `OnBootSec=5min`; no login gate (§2.6)                                                     |
| login gate blocks for up to 30 min                                                      | removed (§2.6)                                                                             |
| `Requires=` on the listener takes down the guest                                        | `Wants=` plus `After=` (§2.8)                                                              |
| epoch bump doesn't restart the guest; sweep unlinks the open image                      | image path in `restartTriggers`; sweep `After=` the guests (§2.4, test 9)                  |
| sweep oneshot never re-runs on activation                                               | `RemainAfterExit=yes` (§2.4)                                                               |
| count cap claimed to bound bytes                                                        | restated; byte exposure accepted under same-owner (§2.4)                                   |
| scratchRoot only created with a scratch volume                                          | gated on scratch or persistent (§2.8)                                                      |
| `NIX_CONF_DIR` disables remote builders                                                 | `NIX_USER_CONF_FILES` (§2.1)                                                               |
| root's `auto` store is local, so I5 is false                                            | `nix.settings.store = mkForce "daemon"` (§2.1)                                             |
| optimise forces keyed on the scratch entry                                              | `hasRwStore` gate (§2.8)                                                                   |
| alert is fleet-wide; counters reset on reboot                                           | instance-scoped rule; counters dropped (§2.8)                                              |

**Round 4 (v0.4): 14 surviving objections** (17 raised).

| v0.4 objection                                                                                         | Resolution                                                                          |
| ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `--verify --repair` holds the GC lock through repairs; auto-GC self-deadlock                           | repair per path outside the lock; verify without repair; `TimeoutStartSec` (§2.6)   |
| a missing chain aborts the verify (`on delete restrict`)                                               | repair D references-first; verify only once D is empty (§2.6 steps 3 and 5, test 6) |
| host applies a truncated export                                                                        | export refuses to write over the cap; nothing is ever truncated (§2.3)              |
| I5 false: the build hook opens the store                                                               | I5 restated (§2.7)                                                                  |
| `epoch` is a runbook for one lost path                                                                 | automatic give-up of positively gone dependencies (§2.6 step 4)                     |
| new alert duplicates `NodeSystemdServiceFailed`; regex has no data path; I7 false; no positive control | no new rule; the existing one covers it (§2.8)                                      |
| sweep deletes a removed-but-running guest's image                                                      | skip held-open images and active guests (§2.4, test 9)                              |
| rollback before the feature pins roots forever                                                         | sweep lands first (§2.9)                                                            |
| disabling leaves no writable store                                                                     | the feature overrides the scratch entry; disabling restores it (§2.8, test 9)       |
| export ordered after the reconcile                                                                     | own timer, no ordering (§2.3)                                                       |
| `drop_caches` unproven and global                                                                      | removed; stale-dentry control in test 6                                             |
| build dirs persist on the volume                                                                       | `D /nix/var/nix/builds` at boot (§2.1, test 14)                                     |
| §2.2/§2.8 contradiction on `Requires=`                                                                 | `Wants=` in both (§2.2)                                                             |

**Round 5 (v0.5): 12 surviving objections** (13 raised).

| v0.5 objection                                                                     | Resolution                                                                                                   |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| live-guest skip pins a disabled guest's roots forever                              | skip only unconfigured running guests (§2.4, test 9)                                                         |
| give-up `--delete` refused by unrelated visited paths; root `.drv` keeps referrers | remove auto roots, then the guest GC decides (§2.6 step 4, test 6)                                           |
| repair through a deriver build: cascades, times out, can't be given up             | substitution only (`--max-jobs 0`); a local build is given up like any unsubstitutable path (§2.6 steps 3–4) |
| missing-by-file misses half-deleted host paths                                     | M by host validity; one guest GC for the outside-E case (§2.6 steps 2 and 5)                                 |
| negative narinfo cache makes 3 runs one observation                                | `narinfo-cache-negative-ttl 0` (§2.6)                                                                        |
| `D` wipes builds on an in-place switch                                             | `D!` (§2.1, test 14)                                                                                         |
| import times out behind a long host GC                                             | non-blocking lock, exit 0 (§2.4 step 4, test 4)                                                              |
| staleness check and per-minute rewrite buy nothing                                 | removed; write on change (§2.3, §2.4)                                                                        |
| alert misquoted; reboot gap unstated                                               | exact expression; gap stated (§2.8)                                                                          |
| no hypervisor check for vsock                                                      | guest-side assertion (§2.1)                                                                                  |
| I4 overclaims (logs)                                                               | restated (§2.7)                                                                                              |

**Round 6 (v0.6): 12 surviving objections** (14 raised). The review reached its
cap. v0.7 applies the fixes below, and no critic has reviewed them.

| v0.6 objection                                                   | Resolution                                                                  |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `--max-jobs 0` doesn't stop the repair cascade                   | `nix-store --realise --repair` (substitution goal only) (§2.6 step 3)       |
| half-deleted host path outside E passes verify                   | guest GC triggered by M \ E with a present directory (§2.6 step 5)          |
| non-blocking import skips silently; window unpriced              | blocking lock, `TimeoutStartSec=infinity`; window restated (§2.4, §4)       |
| keep-outputs ties a `.drv` root to p; give-up contradicts test 6 | remove every auto root over closure⁺; closure check (§2.6 step 4)           |
| `D!` overrides Nix's 7-day rule                                  | initrd `rm -rf` before `mkdir`; no tmpfiles line (§2.1)                     |
| give-up counter location unspecified                             | on the volume (§2.6 step 4, test 6)                                         |
| alert resolves on every retry                                    | verdict units via `OnFailure=`/`OnSuccess=` (§2.8)                          |
| a removed-then-stopped guest waits for a reboot                  | daily periodic sweep (§2.4, test 9)                                         |
| sweep dies with the `microvm-host` aspect                        | `R /nix/var/nix/gcroots/microvm-store` on non-hosts (§2.4)                  |
| `size` ignored after first boot                                  | grow-only `ExecStartPre` (§2.8, test 14)                                    |
| an offline LAN peer cache blocks the give-up forever             | unreachable peers count as absent; a public cache must answer (§2.6 step 4) |
| test 10 can't see non-unit changes                               | `nix-diff` of the toplevel (test 10)                                        |
| (noted) I6 ignores the guest's remote-build access               | I6 and §2.2 restated                                                        |

**Implementation (v0.7.1).** Building v0.7 corrected these points in place; none
changes a guarantee.

| v0.7 text                                                                                                              | Correction                                                                               |
| ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| import `TimeoutStartSec=10min` (§2.4 list) contradicts step 4's `infinity`                                             | `infinity` in both                                                                       |
| one `<unit>-verdict.service` must both fail and clear                                                                  | a failing verdict plus a `-verdict-clear` that resets it (§2.8)                          |
| the `R` line on every host without `microvm.host.enable` reaches guests, so cortex-cuda's drvPath would move (test 10) | guests excluded (§2.4)                                                                   |
| a missing export would fail the import before a guest's first export                                                   | a missing file applies nothing and succeeds; a present bad one still fails (§2.4 step 1) |
| the grow `ExecStartPre` would run a full `e2fsck -f` on every start                                                    | only when the image is smaller than `size` (§2.8)                                        |
| "entry in the upper layer" is ambiguous for a whiteout                                                                 | a whiteout is not an entry; the path stays exported (§2.3)                               |
| M's two cases                                                                                                          | one test: no upper entry and invalid on the host (§2.6 step 2)                           |
| counter reset unspecified                                                                                              | reset on any run that is not unsubstitutable; kept on a failed give-up (§2.6 step 4)     |

**Round 7 (§2.10 in v0.8): 12 surviving objections** (14 raised, from 2 critics).

| v0.8 objection | Resolution |
|---|---|
| ext4 label of 16 bytes truncates `uplink-dev-persist`: no boot | by-id serial mount; serial-length assertion |
| `microvm.volumes` with a mountPoint emits a conflicting fileSystems entry | `mountPoint = null`; the aspect emits fileSystems |
| format guard reads a probe failure as "empty" | format only in the creating run, after the link wait and `blkid -p`; `json64:formatted` |
| `zvolParent` absent; disko doesn't create it | the unit creates it with `-p`; default derived from `disk.zfs-disk-single` |
| zvols inherit `auto-snapshot=false` | `-o com.sun:auto-snapshot=true` |
| migrate never pulled in; 90 s default timeout; running-guest copy | `requiredBy`, `TimeoutStartSec=infinity`, `PrivateMounts`, `fuser` refusal |
| `RequiredBy=` plus a switch restarts the guest | `restartIfChanged = false`, `RemainAfterExit = no` |
| retire deletes unmigrated or rolled-back state; glob risk | assertion; named dirs; migrated-not-stale; guest state check |
| rollback, then forward, loses rollback-window writes | `stale` mark at a virtiofs start; `rsync --delete` re-sync |
| grow vs deploy; smaller size silently skipped | grow at the next start; a smaller size fails; test 19 reworded |
| `primarycache=metadata` doesn't stop double caching and costs I/O | `direct = true`, `primarycache=all` |
| copy size wrong (374 GiB); first start runs inside the deploy | measured 16 GiB + 372 MiB, 2.17M inodes; deploy planned at a checkpoint |
| (minor) the resize unit duplicates `autoResize`; fstrim already defaults on | `autoResize = true`; fstrim line dropped |

**Round 8 (§2.10 in v0.8.1): 4 surviving objections, plus 1 minor.**

| v0.8.1 objection | Resolution |
|---|---|
| generation rollback skips the `stale` mark; retirement deletes the rollback-window writes | forward-side divergence check (`find -newerct`) at every zvol start and before retirement |
| the stale `ExecStartPre` can't be emitted without touching cortex | removed; the forward check replaces it |
| a failed creating run blocks the guest until a manual destroy | `formatted=pending` set at create; the next run completes it |
| rollback after retirement silently boots an empty guest | retired dirs become regular files, so the start fails loudly |
| (minor) §2.9 still said 374 GiB | fixed |

**Round 9 (§2.10 in v0.8.2): 6 surviving objections**, most of them from round
8's own fixes, which the method reads as churn. v0.9 removes machinery instead
of patching it.

| v0.8.2 objection | Resolution |
|---|---|
| the divergence check fires on the retired file; every zvol start fails after retirement | removed: the one-way migration tombstones the directory at migration; no divergence check remains |
| going forward after a rollback, `rsync --delete` erases the zvol writes | removed: no re-sync; a rollback after migration is refused loudly |
| `pending` stuck after `mkfs` | on `pending`, `mkfs -F` without probing |
| the `fuser` check races udev's watch probe | `udevadm settle` before `fuser` |
| leaked zvol remedy is a manual destroy aimed at live data | declarative `destroyStateZvols`, idle and unconfigured only |
| sparse 2 TiB default overcommits; a full pool pauses the VM | defaults from measured use, grow-only; §4 entry; test 21 |

**Round 10 (§2.10 in v0.9): 6 surviving objections.**

| v0.9 objection | Resolution |
|---|---|
| a crash between `migrated` and the tombstone leaves the state unguarded | atomic `RENAME_EXCHANGE` tombstone first; copy from `.pre-zvol`; `migrated` set last; resume from on-disk state |
| a guest whose first backend is zvol can never start | nothing-to-migrate case: tombstone, then `migrated`, no copy |
| "fails loudly" is false (tmpfiles exits 0; virtiofsd loops in activating) | `microvm-state-guard@` oneshot, failing on the tombstone; commit-2 rollback: `HostSilent` stated and tested |
| leaked-zvol remedy can destroy the only copy after a rollback attempt | destroy only names that match no configured guest under any backend; a refused rollback is never a leak |
| test 18 busy-refusal check can't fail | cleared-`migrated` throwaway guest with QEMU up |
| `.pre-zvol` reported as an orphan; stale "retired" text | `directPaths` lists both until `dropPreZvolBackup` |
