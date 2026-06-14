# Runbook: Restore media-pg from an in-cluster snapshot

**Cluster:** axon k3s · **Namespace:** `media` · **Operator:** CloudNativePG

Use this when the in-cluster Longhorn `volumeSnapshot` backups still exist
(nightly 04:00 + on-demand) and you need to either **verify** they restore
(non-destructive drill) or **recover** the live `media-pg` cluster from one.

If the whole cluster / Longhorn is gone and only the NAS copies survive, use
[media-pg-restore-from-nas.md](media-pg-restore-from-nas.md) instead.

```bash
export KUBECONFIG=$HOME/.config/kube/config
NS=media
```

## Facts you must know before touching anything

- **A snapshot is only consumed at bootstrap.** CNPG reads a snapshot/Backup
  _only_ via `bootstrap.recovery` on a **new** Cluster. Deleting a read replica
  does **not** test or use a snapshot — the operator re-clones the replica with
  `pg_basebackup` streaming from the primary, and drops HA for that window. The
  only way to consume a snapshot is a recovery-bootstrap of a fresh Cluster.
- **Recovery is to-backup-point only — no PITR.** There is no WAL archive /
  object store. An **online (hot)** snapshot is self-contained because CNPG
  holds the WAL needed to reach its own consistency point inside the snapshot's
  `pg_wal` (via a temporary replication slot for the backup's duration). A
  **cold** (`online: false`) snapshot is unambiguously self-contained (no
  temp-slot dependency). A restore reaches exactly the backup's stop point and
  cannot go past it.
  - Aside: `waitForArchive: true` is set with no real archive destination.
    Backups still report `completed`, but it is a latent footgun.
- **Databases and role secrets survive a Cluster delete.** The 12 app databases
  are independent `Database.postgresql.cnpg.io` CRs
  (`databaseReclaimPolicy: retain`, no ownerRef) and the 7 `media-pg-*-password`
  Secrets are ArgoCD-managed. They are _not_ in the snapshot — they reconcile
  idempotently against the recovered PGDATA after recreate. Leave them
  untouched.
- **ArgoCD pause is the lever** for any imperative CNPG surgery on a live
  cluster: scale `argocd-application-controller` to 0 so selfHeal cannot fight
  the recreate. This is also the validated clean-shutdown lever for maintenance.
- **Recreating the Cluster resets instance serials to 1.** A fresh
  recovery-bootstrap yields `media-pg-1` + `media-pg-2` (serials only increment
  on a live cluster; in-place renumber is impossible).
- **Superuser access is disabled** (`enableSuperuserAccess: false`). In-pod
  `psql -U postgres` works via local **peer auth** as the `postgres` OS user. Do
  NOT expect a superuser password/secret to exist.
- **`Backup` is ambiguous.** Longhorn also defines a `Backup` kind, so the
  `backup` short-name resolves to `backups.longhorn.io`. Always use the FQN
  **`backups.postgresql.cnpg.io`** for CNPG backups.

---

## Mode A — Non-destructive verification drill (zero prod impact)

Run this periodically to prove the snapshots restore, and as a pre-flight gate
before any destructive restore. It touches nothing in prod.

1. **Take a fresh manual backup** (validate a _current_ snapshot):

   ```bash
   cat <<'EOF' | kubectl apply -f -
   apiVersion: postgresql.cnpg.io/v1
   kind: Backup
   metadata: { name: media-pg-predrill, namespace: media }
   spec:
     cluster: { name: media-pg }
     method: volumeSnapshot
   EOF
   kubectl -n $NS wait --for=jsonpath='{.status.phase}'=completed \
     backups.postgresql.cnpg.io/media-pg-predrill --timeout=10m
   ```

2. **Add a temporary apiserver-egress policy** for the throwaway cluster. The
   existing `allow-media-pg-apiserver-egress` CNP selects only
   `cnpg.io/cluster=media-pg`; `kube-apiserver` is a Cilium _entity_ (not an
   endpoint) so it needs an explicit allow. (In-cluster DNS / operator traffic
   is already covered by `allow-internal-egress`; nothing selects the throwaway
   on ingress, so the operator's instance-manager calls on 8000 are accepted.)

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

3. **Bootstrap a throwaway recovery cluster** from the snapshot:

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
         backup: { name: media-pg-predrill }
   EOF
   kubectl -n $NS wait --for=condition=Ready cluster/media-pg-verify --timeout=15m
   ```

4. **Validate the restore.** A psql error or a missing table here = **drill
   fail** (no `|| true` — a missing table MUST fail):

   ```bash
   POD=media-pg-verify-1
   kubectl -n $NS exec $POD -c postgres -- pg_isready
   # databases present (expect sonarr-main/-log, radarr-*, lidarr-*, whisparr-*,
   # prowlarr-*, bazarr, romm):
   kubectl -n $NS exec $POD -c postgres -- psql -U postgres -c '\l'
   # row counts on REAL tables (Series/Episodes are sonarr; Movies is radarr):
   kubectl -n $NS exec $POD -c postgres -- \
     psql -U postgres -d sonarr-main -tAc 'select count(*) from "Series"'
   kubectl -n $NS exec $POD -c postgres -- \
     psql -U postgres -d radarr-main -tAc 'select count(*) from "Movies"'
   # recovery reached consistency (no FATAL/PANIC in WAL replay):
   kubectl -n $NS logs $POD -c postgres | grep -iE 'consistent recovery|FATAL|PANIC|redo done' | tail
   ```

   Compare the same counts against prod (`media-pg-rw`, same `exec` + peer-auth
   form) to confirm data parity.

5. **Tear down** (regardless of outcome):

   ```bash
   kubectl -n $NS delete cluster media-pg-verify
   kubectl -n $NS delete pvc -l cnpg.io/cluster=media-pg-verify
   kubectl -n $NS delete ciliumnetworkpolicy allow-media-pg-verify-apiserver-egress
   # keep media-pg-predrill if recent — reusable as a restore source
   ```

6. **If validation failed: STOP.** The backups are broken and prod was never
   touched. Capture the failure mode and treat it as an incident — do not
   proceed to Mode B.

---

## Mode B — Recover the live media-pg cluster (destructive, maintenance window)

Use this when `media-pg` itself is broken/lost but the snapshots are intact.
Brief media-stack downtime. **Run Mode A first** unless the live cluster is
already down. Order matters.

1. **Pause ArgoCD** (freeze selfHeal fleet-wide):

   ```bash
   kubectl -n argocd scale statefulset argocd-application-controller --replicas=0
   ```

2. **Quiesce DB clients** (clean disconnect, quiet snapshot). Scale the media
   app deployments that hold Postgres connections to 0 (sonarr/radarr/lidarr/
   whisparr/prowlarr/bazarr/romm). **Record current replica counts first.**

3. **Capture the live cluster spec** so the recreate keeps every managed role,
   database, backup, monitoring, and anti-affinity setting exactly:

   ```bash
   kubectl -n media get cluster media-pg -o yaml > /tmp/media-pg-current.yaml
   # Edit into /tmp/media-pg-recreate.yaml: strip status + runtime metadata (uid,
   # resourceVersion, creationTimestamp, generation, managedFields, .status),
   # then add the bootstrap.recovery stanza from step 6.
   ```

   (If the live cluster object is already gone, recreate from the last-known
   spec / git rather than capturing.)

4. **Take a fresh cutover backup** — the restore source _and_ fallback. Use a
   **cold** (`online: false`) snapshot: clients are already quiesced (step 2),
   so fencing cost is near zero, and a cold snapshot removes the temp-slot WAL
   dependency — the safest source for a one-shot.

   ```bash
   cat <<'EOF' | kubectl apply -f -
   apiVersion: postgresql.cnpg.io/v1
   kind: Backup
   metadata: { name: media-pg-cutover, namespace: media }
   spec:
     cluster: { name: media-pg }
     method: volumeSnapshot
     online: false
   EOF
   kubectl -n media wait --for=jsonpath='{.status.phase}'=completed \
     backups.postgresql.cnpg.io/media-pg-cutover --timeout=10m
   ```

5. **Delete the cluster** (snapshots survive; old PVCs may cascade — fine, we
   restore from the snapshot):

   ```bash
   kubectl -n media delete cluster media-pg
   kubectl -n media delete pvc -l cnpg.io/cluster=media-pg   # ensure clean recreate
   ```

6. **Recreate from recovery** using the captured spec with the bootstrap added.
   The recreate reuses the name `media-pg`, so the existing
   `allow-media-pg-apiserver-egress` CNP already applies — no temp CNP needed.

   ```yaml
   spec:
     # ...all captured fields (instances: 2, storage, affinity, managed.roles,
     #    monitoring, backup.volumeSnapshot)...
     bootstrap:
       recovery:
         backup: { name: media-pg-cutover }
   ```

   ```bash
   kubectl apply -f /tmp/media-pg-recreate.yaml
   kubectl -n media wait --for=condition=Ready cluster/media-pg --timeout=20m
   ```

   Instance 1 recovers from the snapshot; instance 2 clones from it ⇒
   **media-pg-1, media-pg-2** (serials reset on the new Cluster object).

7. **Verify:**

   ```bash
   kubectl -n media get cluster media-pg \
     -o jsonpath='phase={.status.phase} ready={.status.readyInstances} primary={.status.currentPrimary} healthy={.status.instancesStatus.healthy}{"\n"}'
   # expect: phase=Cluster in healthy state, ready=2, healthy=[media-pg-1, media-pg-2]
   kubectl -n media get pvc -l cnpg.io/cluster=media-pg   # media-pg-1, media-pg-2
   # Database CRs must re-apply against the recreated cluster:
   kubectl -n media get databases.postgresql.cnpg.io \
     -o custom-columns='NAME:.metadata.name,APPLIED:.status.applied'
   # expect APPLIED=true for all 12
   ```

   Confirm data present (row counts as in Mode A step 4, on `media-pg-rw`).

8. **Re-enable ArgoCD:**

   ```bash
   kubectl -n argocd scale statefulset argocd-application-controller --replicas=1
   # Resync the media app; confirm Synced/Healthy. Verify it does NOT try to
   # revert .spec.bootstrap — git never sets it, so a live recovery bootstrap is
   # not drift and selfHeal leaves it alone. ArgoCD re-applies managed.roles
   # (passwords come from the surviving secrets, not the snapshot).
   ```

9. **Unquiesce apps:** scale media deployments back to the recorded counts;
   confirm each connects to `media-pg-rw`, can log in with its role, and reads
   its DB.

### Rollback

At every step before verification succeeds the snapshots (`media-pg-cutover`
plus the nightly history) are intact. If the recreate fails, re-run step 6
against `media-pg-cutover` (or an earlier nightly). **Never delete a snapshot
until the new cluster is verified healthy and serving apps.**

---

## Notes

- snapshot-only / in-cluster backups are **not** disaster recovery — they live
  on the same Longhorn system as the live data. Off-cluster DR (NAS) is the
  companion runbook. WAL archiving / PITR remains the one deferred DR gap.
- No nix-config change is involved: `media-pg.nix` never sets `.spec.bootstrap`,
  and the whole operation is a runbook plus one-time imperative execution.
