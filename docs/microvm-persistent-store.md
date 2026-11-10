# MicroVM guests: a persistent store over the host's shared store

Status: **draft v0.7** (2026-11-09). Owner request: "the devshell loss on every
reboot is really painful; we need a real solution for persistence." The
adversarial review hit its cap at round 6 (K=6, the cap for a change to the live
system). Objections per round: 17, 16, 17, 14, 12, 12. v0.7 applies round 6's 12
fixes, and **no critic has reviewed it**. §8 maps every objection to its
resolution.

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
  `/nix/.rw-store/store/` that `nix path-info` accepts.
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

E is written sorted to `/cache/.microvm-store/roots`, through a temp file and a
`rename`, but only when its content changed, so an idle guest triggers no host
import. The timer has `OnBootSec=1min` and `OnUnitActiveSec=1min`, with no
ordering on the reconcile, so a long repair never delays it (round 4). Test 13
records how long a run takes.

### 2.4 Root import (host)

Per persistent-store guest:

- `microvm-store-roots@<guest>.path`: `PathChanged=` on the guest's export file.
  virtiofsd writes the file on the host, so the host's inotify sees the change.
- `microvm-store-roots@<guest>.timer`: every 15 minutes, as a backstop.
- `microvm-store-roots@<guest>.service`: oneshot, `RemainAfterExit=no`,
  `TimeoutStartSec=10min`. It runs a host program (`writers.writePython3Bin`),
  in five steps:

1. **Open without following anything the guest controls.** Take a directory fd
   on the guest's host-owned `/cache` state directory
   (`stateDir <guest> "/cache"`). From it, open `.microvm-store` with
   `O_DIRECTORY|O_NOFOLLOW`, then `roots` with
   `O_RDONLY|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC`. `fstat` that fd and require
   `S_ISREG`. Read it once, through the fd, at most `256 × maxExportPaths`
   bytes. A symlink, FIFO or device is refused before any read can block.
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
  - any image that some process holds open (a scan of `/proc/*/fd`);
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
  (tmpfiles). No guest can still be running once the host module is gone,
  because its units vanish and switch-to-configuration stops them (round 6). The
  images on `/cache/microvms` stay until the owner removes `/cache/microvms`,
  and §4 names this.

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
   6). If p is unsubstitutable on 3 consecutive runs, the guest gives up on it:
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

   Before the verify, if **M \ E has a member whose directory exists**, which
   means a host path half-deleted by an interrupted host GC, the reconcile runs
   the guest's GC once. That member is dead in the guest, because it is outside
   E and R includes temp and runtime roots. The GC visits its directory, and
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
fragment adds an `ExecStartPre` on `microvm@<guest>`: `truncate -s '>'<size>M`
on the image, then `e2fsck -fp` and `resize2fs`. That grows the image and never
shrinks it. Shrinking needs an `epoch` bump, and an assertion can't see the old
size, so the option's description says so (round 6).

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
a failing verdict, and its `OnSuccess=` starts a passing one. So a retry that is
still running (`activating`) never clears the failure, and the alert stays on
until a run succeeds (round 6). A reboot still resets the failed state, and the
alert then fires again within the first run plus `for: 5m`. That gap is
accepted.

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

A rollback to before commit 1 is the only way to leave `gcroots/microvm-store/`
and the image behind, and §4 names it (round 4).

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
   - `.microvm-store` as a symlink;
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
