# Single-replica volumes: keep each copy on its pod's node

Status: **v0.2** (2026-11-13). §2.1 is built; §2.2 is blocked (§6).

## 1. Problem

The `longhorn-single` StorageClass (`storage/cloudnative-pg/cloudnative-pg.nix`)
gives each volume one Longhorn copy. Its stated design is that the workload owns
redundancy: CloudNativePG runs two instances with required pod anti-affinity, so
the two instances, and their data, sit on different nodes.

The data half is not enforced. The class sets only `numberOfReplicas: "1"` and
`staleReplicaTimeout`. With `dataLocality` left at `disabled`, Longhorn places
each copy wherever its scheduler likes, and the pod reads it over the network.
Anti-affinity separates the pods, not their copies.

Measured 2026-11-12, 24 `longhorn-single` volumes:

| Workload      | Instance 1: pod / copy | Instance 2: pod / copy | One node holds both copies |
| ------------- | ---------------------- | ---------------------- | -------------------------- |
| hindsight-pg  | axon-01 / axon-02      | axon-03 / axon-02      | axon-02                    |
| media-pg      | axon-01 / axon-02      | axon-03 / axon-02      | axon-02                    |
| immich-pg     | axon-01 / axon-01      | axon-03 / axon-01      | axon-01                    |
| matrix-pg     | axon-03 / axon-01      | axon-01 / axon-01      | axon-01                    |
| monitoring-pg | axon-01 / axon-01      | axon-03 / axon-01      | axon-01                    |
| paperless-pg  | axon-01 / axon-01      | axon-03 / axon-01      | axon-01                    |
| coder-pg      | axon-01 / axon-01      | axon-03 / axon-02      | no                         |

So six of seven database clusters lose both instances when one node goes. That
is what happened on 2026-11-12, when axon-01's Longhorn instance-manager became
unreachable: matrix-pg, monitoring-pg and paperless-pg went down entirely.

**Garage, one level up:** `garage-storage-0`, `-1` and `-2` are three
one-replica StatefulSets with no anti-affinity or spread constraint, and all
three pods run on axon-03. Garage's own replication is across those pods, so it
is also on one node. Two of its three data volumes are local to axon-03; the
third's copy is on axon-02.

The llama-cpp model volumes (3 × 30 Gi) are caches and do not matter for
redundancy.

## 2. Design

### 2.1 Data locality `best-effort`

Set `dataLocality: best-effort` on the class and on every existing
`longhorn-single` volume. With it, when a volume attaches on a node holding no
copy, Longhorn builds a copy on that node and then removes the remote one. The
copy follows the pod, so CNPG's anti-affinity now also separates the data.

**Rejected: `strict-local`.** Longhorn 1.13's admission webhook
(`webhook/resources/volume/validator.go`) refuses to convert a volume to or from
`strict-local` unless it is detached. It also refuses to attach a strict-local
volume on any node other than its copy's: "moving a strict-local volume to
another node is not supported". The Kubernetes scheduler does not know that, so
a rescheduled database pod could land on another node and never attach.
`best-effort` has neither limit: it can be set on attached volumes and lets a
pod move, carrying its data with it.

**What changes for drains:** under the existing `node-drain-policy`
(`block-if-contains-last-replica`), draining a node evicts its database
instance. CNPG recreates the pod on a node that satisfies anti-affinity. The
volume attaches there remotely, Longhorn builds the local copy, and the drained
node's copy stops being the last one, so the drain completes. Drains then carry
the data off the node instead of blocking forever or needing a policy override,
as they did on 2026-11-12. They take as long as the copy does (single-digit GB
here).

### 2.2 Garage spread

Give the three `garage-storage-N` StatefulSets one shared label and a required
pod anti-affinity on it (`kubernetes.io/hostname`), so each storage node runs on
its own axon. With `best-effort` locality, their volumes follow. This is a pod
move for two of the three, not a data-loss risk, since Garage replicates and the
copies move one at a time.

## 3. Rollout

1. **The class.** StorageClass `parameters` are immutable. The class is deleted
   and recreated with `dataLocality: "best-effort"`, through Argo's
   `Replace=true` sync option on that one resource. It affects only new volumes;
   existing PVCs keep working, because a class is read only at provisioning.
2. **The existing volumes.** Patch each of the 24 Longhorn volumes'
   `spec.dataLocality` to `best-effort`, one workload at a time, then wait for
   its copy to be local before the next. This is allowed on attached volumes
   (neither value is `strict-local`). The volume spec is Longhorn's, not ours: a
   one-time `kubectl patch`, recorded here, and the class makes new volumes
   right by construction.
3. **Garage anti-affinity** (§2.2), then its pods move one at a time.
4. **Then the remaining node work:** axon-02 and axon-03 drain with no policy
   change and reboot for kernel 7.3.3 and their new Cilium pod ranges
   (`docs/address-plan.md` §8 step 6).

About 65 GB moves in step 2 (the remote copies' used size, of which media-pg is
24 GB and the gpt-oss models 24 GB). Every node has more than 1.7 TB available.

## 4. Acceptance

- Every `longhorn-single` volume's copy is on the node running its pod.
- No database cluster has both instances' copies on one node.
- The three Garage storage pods run on three different nodes.
- Control: today's table (§1) fails all three checks, so the predicate tells the
  states apart.
- Live: the axon-02 drain completes under `block-if-contains-last-replica`.

## 5. Open questions

1. Roll out now, before the axon-02 and axon-03 reboots, or reboot first with a
   one-time downtime for hindsight-pg and media-pg? Recommended: now. It is the
   reason the drain failed.
2. The llama-cpp model caches: include them (harmless, 24 GB to move), or leave
   them `disabled`? Recommended: include them, for one rule across the class.

## 6. As built (2026-11-12/13)

- **§2.1, done.** The class has `dataLocality: best-effort` (Argo diffs it
  client-side and force-replaces it, since its parameters are immutable). All 14
  attached `longhorn-single` volumes are `best-effort`, and each copy is on its
  pod's node. Every CNPG cluster's two instances now have their copies on
  different nodes.
- **Incident during the moves:** at 07:45:16Z on 2026-11-13, axon-02's Longhorn
  instance-manager dropped its data connections while it was the source for both
  media-pg copies (23 GB). Every volume with a copy on axon-02 faulted at once.
  The single-copy media-pg-2 auto-salvaged, and CNPG failed over to media-pg-1.
  Replication is asynchronous, so the old primary's last writes may be lost.
  Lesson: one large move per source node at a time.
- **§2.2, blocked.** The Garage operator cannot roll out a template change:
  every GarageNode is `ReconcileFailed` ("managed persistent volume claims
  require enabled admission webhooks"), and its own `DiscoveryCompatible`
  condition warns that Garage v2.3.0 with Kubernetes discovery would crash-loop
  on restart ("Set spec.image to v2.4.1 or newer (or disable spec.discovery)
  before the next restart"). The anti-affinity was committed and reverted
  (6b7e4d61). All three storage pods are still on axon-03.
- **Leftover:** four detached Retain volumes (old copies of hindsight-pg-2,
  coder-pg-1/2 and two llama-cpp models), with no PVC in use. Owner to decide on
  deletion.
