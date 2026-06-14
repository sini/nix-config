# Runbook: Restore media-pg from the NAS (off-cluster DR)

**Cluster:** axon k3s · **Namespace:** `media` · **Operator:** CloudNativePG
**Validated:** 2026-06-14

Use this when the cluster / Longhorn is lost and the in-cluster CSI
VolumeSnapshots are **gone** — only the off-cluster copies on the NAS survive.
If in-cluster snapshots still exist, use
[media-pg-restore-in-cluster.md](media-pg-restore-in-cluster.md) instead.

```bash
export KUBECONFIG=$HOME/.config/kube/config
NS=media
```

## Facts you must know before touching anything

- **What lives on the NAS.** The Longhorn NFS BackupTarget
  (`nfs://…:/volume2/longhorn-backups`) holds off-cluster `Backup` objects for
  the CNPG DB volumes (`type:bak` ScheduledBackups) and the app-config volumes
  (`media-config-backup` RecurringJob). After a cluster loss the BackupTarget
  re-discovers them on sync.
- **Recovery model.** You cannot bootstrap CNPG directly off a Longhorn NAS
  backup. The path is: **reconstruct an in-cluster VolumeSnapshot from the NAS
  backup handle, then recover from that snapshot.** No surviving in-cluster
  snapshot is relied on.
- **GOTCHA — do not "simulate DR" by deleting a managed snapshot.** The
  `longhorn-backup-nfs` VolumeSnapshotClass is `deletionPolicy: Delete`, so
  deleting a CNPG-managed VolumeSnapshot **cascade-deletes the NAS backup**.
  Always build an INDEPENDENT, `Retain` VolumeSnapshot (step 2).
- **Superuser access is disabled** (`enableSuperuserAccess: false`). In-pod
  `psql -U postgres` works via local **peer auth** as the `postgres` OS user.
- **`Backup` is ambiguous.** In `longhorn-system` use the FQN
  `backups.longhorn.io`.
- **The 12 Database CRs and 7 password Secrets** are independent of the Cluster
  and reconcile idempotently against the recovered PGDATA — they are not in the
  backup.

---

## Step 1 — Find the NAS Longhorn Backup

```bash
kubectl -n longhorn-system get backups.longhorn.io \
  -o custom-columns='NAME:.metadata.name,VOL:.status.volumeName,STATE:.status.state,SIZE:.status.size'
```

Pick the backup for the target DB volume. The CSI handle is
`bak://<volumeName>/<backupName>`.

## Step 2 — Reconstruct a pre-provisioned VolumeSnapshot (`Retain`)

`Retain` means teardown never touches the NAS backup. Substitute the handle from
step 1.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotContent
metadata: { name: media-pg-nasrestore-content }
spec:
  deletionPolicy: Retain
  driver: driver.longhorn.io
  source: { snapshotHandle: "bak://<volumeName>/<backupName>" }
  volumeSnapshotClassName: longhorn-backup-nfs
  volumeSnapshotRef: { name: media-pg-nasrestore, namespace: media }
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata: { name: media-pg-nasrestore, namespace: media }
spec:
  source: { volumeSnapshotContentName: media-pg-nasrestore-content }
  volumeSnapshotClassName: longhorn-backup-nfs
EOF
kubectl -n media wait --for=jsonpath='{.status.readyToUse}'=true \
  volumesnapshot/media-pg-nasrestore --timeout=10m
```

## Step 3 — Recover a cluster from the reconstructed snapshot

The DR path uses `bootstrap.recovery.volumeSnapshots` (no CNPG `Backup` object
needed).

Choose the target:

- **Drill / verify (non-destructive):** name it `media-pg-verify`,
  `instances: 1`, and first add the temporary apiserver-egress policy below (a
  throwaway name is not covered by the existing
  `allow-media-pg-apiserver-egress` CNP, which selects only
  `cnpg.io/cluster=media-pg`).
- **Real recovery to prod:** name it `media-pg`, use the captured/last-known
  prod spec (`instances: 2`, storage, affinity, managed.roles, monitoring,
  backup) with the bootstrap stanza below grafted in. The name `media-pg` reuses
  the existing CNP, so no temp policy is needed. Pause ArgoCD first
  (`kubectl -n argocd scale statefulset argocd-application-controller --replicas=0`)
  and re-enable it after verification — see the in-cluster runbook's Mode B for
  the full quiesce / ArgoCD / unquiesce sequence.

Temporary apiserver-egress policy (drill only):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: { name: allow-media-pg-verify-apiserver-egress, namespace: media }
spec:
  endpointSelector: { matchLabels: { cnpg.io/cluster: media-pg-verify } }
  egress:
    - toEntities: [kube-apiserver]
      toPorts:
        - ports: [{port: "443", protocol: TCP}, {port: "6443", protocol: TCP}]
EOF
```

Recover (drill form shown — swap name/instances/spec for prod):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata: { name: media-pg-verify, namespace: media }
spec:
  instances: 1
  storage: { size: 20Gi, storageClass: longhorn-single }
  bootstrap:
    recovery:
      volumeSnapshots:
        storage:
          name: media-pg-nasrestore
          kind: VolumeSnapshot
          apiGroup: snapshot.storage.k8s.io
EOF
kubectl -n media wait --for=condition=Ready cluster/media-pg-verify --timeout=15m
```

## Step 4 — Verify parity

In-pod peer auth (superuser disabled); compare against prod `media-pg-rw` if it
is still serving:

```bash
kubectl -n media exec media-pg-verify-1 -c postgres -- \
  psql -U postgres -d sonarr-main -tAc 'select count(*) from "Series"'
kubectl -n media exec media-pg-verify-1 -c postgres -- \
  psql -U postgres -d radarr-main -tAc 'select count(*) from "Movies"'
```

For a **real prod recovery**, also confirm the Database CRs re-applied
(`APPLIED=true` for all 12) and that apps reconnect to `media-pg-rw` — see the
in-cluster runbook's Mode B steps 7–9.

## Step 5 — Teardown (drill) — confirm the NAS backup survives

`Retain` content means the NAS backup is untouched; verify it.

```bash
kubectl -n media delete cluster media-pg-verify
kubectl -n media delete pvc -l cnpg.io/cluster=media-pg-verify
kubectl -n media delete volumesnapshot media-pg-nasrestore
kubectl delete volumesnapshotcontent media-pg-nasrestore-content
kubectl -n media delete ciliumnetworkpolicy allow-media-pg-verify-apiserver-egress
kubectl -n longhorn-system get backups.longhorn.io <backupName>   # MUST still exist
```

---

## Restoring an app-config (non-CNPG) volume

For an app-config volume (Sonarr/Radarr/etc. config, not Postgres), step 3 is
not a CNPG Cluster but a **PVC with the reconstructed VolumeSnapshot as
`dataSource`** (size = the snapshot's `restoreSize`), then mount it into the
app. Steps 1, 2 and 5 are identical.

## Longhorn RecurringJob enrollment note

Recurring jobs select by **Volume CR** label. Longhorn does **not** retro-sync
PVC labels onto pre-existing volumes — they sit in the auto-assigned `default`
group. The declarative `persistence.<vol>.labels` / CNPG
`inheritedMetadata.labels` apply only at volume provision. EXISTING volumes must
be labeled directly, once:

```bash
kubectl -n longhorn-system label volume <vol> \
  recurring-job-group.longhorn.io/<group>=enabled \
  recurring-job-group.longhorn.io/default-
```

Verify a job picks them up with a one-off run (bypasses cron + ArgoCD), then
read the pod log for "Found N volumes":

```bash
kubectl -n longhorn-system create job --from=cronjob/<rjob> <name>
```
