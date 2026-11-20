# Plan: the Syncthing hub into the cluster

Status: LIVE 2026-11-20 (f4de2175, 2b968b50, 81a0b082). The cluster hub serves
cortex, bitstream and uplink-dev at 100% completion; blade switches when its
build finishes; patch waits on its own session. uplink's /var/lib/syncthing
stays until 2026-11-27 with no conflicts, then is wiped. Part of the uplink plan
(docs/uplink-maintenance-plan.md, Tier 2 item 13).

## Summary

Move uplink's always-on Syncthing hub (core/network/syncthing/hub.nix) into a
single-replica cluster pod on a Longhorn volume, keeping its device identity so
no member re-pairs. The folders live on the Longhorn volume, which Longhorn's
nightly backup copies off the cluster to the NAS, as it does for headscale.

## What runs today (measured 2026-11-19)

- **What it is.** One system daemon on uplink. It mirrors each replicating
  user's directories under `/var/lib/syncthing/<user>/`, 3.9 GB in total:
  - sini: `.claude/projects` (3.8 GB) and `.claude/memory` (3.1 MB, with
    `staggered` history);
  - vic: 64 KB.
- **Versioning.** `trashcan` 30 days, except `memory`, which keeps `staggered`
  history for 30 days.
- **Members.**
  - sini: cortex, bitstream, patch, blade, uplink-dev.
  - vic: bitstream only. While uplink is down, vic's folders exist only on
    bitstream: no data is lost, but there's no second copy.
- **Wiring.**
  - Discovery and relays are off; each device dials the others' listed
    addresses.
  - Members dial the hub at `tcp://uplink.prod.json64.dev:22000` and
    `tcp://uplink.ts.json64.dev:22000`.
  - Port 22000 is open on uplink's tailnet interface only.
- **Identity.** The hub's device identity is uplink's host agenix secret
  `syncthing-uplink.age`. Its public `.crt` and `.id` are committed.

## Design

1. **Workload.**
   - A cluster aspect `kubernetes.services.network.syncthing-hub`.
   - One replica with `strategy: Recreate`, since Syncthing is a single writer
     on a ReadWriteOnce volume.
   - Upstream's `syncthing/syncthing` image, tracking its major tag through
     `images/`.
   - Hardened like headscale: non-root, read-only root filesystem.
2. **Config.**
   - Nix renders `config.xml` from the same inputs hub.nix uses: member devices,
     per-user folders, folder IDs `stfolder-<sha256 user:path>`, the versioning
     rules, and announce and relays off.
   - The GUI and API listen on localhost only, with an API key from a generated
     secret.
   - An init container copies `config.xml` into place on every start. That keeps
     hub.nix's `overrideDevices` and `overrideFolders` semantics: nix is the
     source of truth.
   - A config hash on the pod restarts it on change.
3. **Identity.** `cert.pem` and `key.pem` are uplink's hub identity. The key
   moves from uplink's host secret to the cluster's SOPS output (the same
   rekeyFile, plus `sopsOutput`). Because the device ID is unchanged, members
   only see a new address.
4. **Shared logic.** The folder and device logic moves to a `_syncthing-hub.nix`
   helper that both hub.nix and the cluster aspect import, as
   `_headscale-settings.nix` is shared. The two can't drift.
5. **Addressing.**
   - A LoadBalancer Service on a new `syncthing-hub` assignment (10.11.0.x,
     BGP-advertised, LAN-routable), port 22000/tcp.
   - The hub publishes `tcp://syncthing.json64.dev:22000`. The name resolves to
     the VIP on the LAN and isn't internet-routable.
   - Off-LAN members (patch roaming) don't reach the hub. They keep syncing with
     bitstream and cortex over the tailnet, because every member is in the
     same-user mesh, and they catch up with the hub when back on the LAN. I'd
     accept that rather than publish 22000 on the WAN.
6. **Peer records.** The hub's `syncthing-peers` record becomes a cluster emit
   (`isHub = true`, the new address). The members' collect pipe gains a cluster
   source, as served-domains and container-registries have. The hub receives the
   member records through a `cluster-collect-syncthing-peers` pipe and
   `replicateHome` through a matching one.
7. **Network policy.** Ingress on 22000 from the LAN and tailnet ranges
   (10.0.0.0/8 and 100.64.0.0/10), nothing else. Egress to members on their
   per-user ports (22000 + `syncthingOffset`).
8. **Storage.** A 20Gi Longhorn PVC, with room for `.stversions` growth, in the
   nightly off-cluster backup group.

## Rollout

1. **Land it idle.** The aspect and volume go in with `replicas = 0`, behind a
   `live` setting. uplink stays the hub.
2. **Seed the data.**
   - Recommended: start empty. The hub pulls everything from the members. A
     device with no index for a folder only receives, so starting empty deletes
     nothing elsewhere.
   - Cost: the hub's `.stversions` history is lost. Its only unique content is
     `memory`'s 30 days of staggered versions; the trashcan copies are just
     deleted session logs.
   - If you want that history, copy `/var/lib/syncthing/<user>/` into the volume
     first, with a temporary pod and rsync over SSH from uplink. Not
     `kubectl port-forward`, which stalled on the registry copy.
3. **Cut over.**
   - Set `live`, so the pod starts and the members' records carry the new
     address.
   - Deploy the members: cortex, bitstream, blade, uplink-dev and patch. Their
     config updates in place; uplink-dev's runner must not change.
   - Then drop the hub from uplink (`isHub` and the hub include) and deploy
     uplink.
4. **Verify.**
   - Every member shows the hub connected.
   - Each folder reports "Up to Date" on the hub, with its global size matching
     uplink's.
   - A test file written on cortex reaches bitstream through the hub.
5. **Clean up.** After a week with no conflicts, wipe `/var/lib/syncthing` from
   uplink's persist.

Rollback before step 5: unset `live`, put `isHub` back on uplink, and redeploy.
The identity is the same, so members reconnect to uplink.

## Found at cutover

- The Service needs `externalTrafficPolicy: Local`. With Cluster, a connection
  reaching another node arrives SNATed to that node's pod-range address, Cilium
  labels it world, and the LAN-range ingress rule drops it (81a0b082).
- uplink's `var-lib-syncthing.mount` fails to stop on switch: the bind shares
  the persist dataset uplink-dev's virtiofsd holds. Harmless; it clears at
  uplink's next reboot.

## Decided (owner, 2026-11-19)

- Seed the hub empty. The hub's own `.stversions` history is not carried over.
- The hub is LAN-only. Off-LAN members sync through bitstream and cortex over
  the tailnet; no WAN port-forward.
- vic keeps the hub as a second copy, from its new home.

## Not covered

Changing which directories replicate, and moving member daemons anywhere.
