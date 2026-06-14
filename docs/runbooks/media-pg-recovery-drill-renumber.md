# media-pg Recovery Drill + Renumber to 1,2 — Design & Runbook

**Date:** 2026-06-13 **Cluster:** axon k3s, namespace `media`, CNPG operator
1.29.1 **Status:** EXECUTED 2026-06-14 — Phase 0 integrity gate passed (restore
parity verified), Phase 1 renumber to 1,2 complete (serial reset, data parity,
all apps reconnected, ArgoCD Synced/Healthy). Retained as the reusable
recovery/DR runbook.

## Problem

`media-pg` (CloudNativePG, 2-instance HA backing the media stack) has two
issues:

1. **Untested recovery.** Backups are in-cluster longhorn `volumeSnapshot`
   (`type: snap`), nightly 04:00 + on-demand. No barman object store, no WAL
   archive (`barmanObjectStore` empty, `plugins` empty), `online: true` /
   `waitForArchive: true`. Snapshots live on the _same_ longhorn system as the
   live data. No restore has ever been performed — we do not actually know the
   backups are restorable.
2. **Disjoint instance numbering (1,3).** On day 1, a double-interrupted reboot
   corrupted media-pg-2 mid-rejoin; the remedy was pod+PVC delete, and CNPG
   re-provisioned under a _new_ serial → `media-pg-1` + `media-pg-3`. CNPG
   instance serials only increment on a live cluster, so the gap is permanent
   without recreating the Cluster object. It muddies the CNPG
   dashboards/metrics.

## Scope

**In:** prove the existing snapshot backup restores; renumber 1,3 → 1,2; produce
a reusable runbook. **Out (deferred, possible follow-up spec):** off-cluster
object store / WAL archiving for real DR + point-in-time recovery. The current
story stays snapshot-only.

## Key facts that shape the design

- **Renumber == recreate.** The instance serial lives on the Cluster object;
  deleting and recreating the Cluster CR resets it to 1. So a fresh
  recovery-bootstrap yields `media-pg-1` + `media-pg-2`.
- **Recovery == the only way to consume a snapshot.** A CNPG snapshot/Backup is
  read _only at cluster bootstrap_ (`bootstrap.recovery`). Deleting a read
  replica does **not** test the snapshot — the operator rebuilds a replica via
  `pg_basebackup` streaming from the **primary**, never from a VolumeSnapshot
  (this is exactly what we watched media-pg-1 do on 2026-06-13 23:39 after the
  whole-cluster drain). Replica-delete also drops HA for the rebuild window,
  which is the day-1 corruption scenario. Therefore the integrity test must be a
  **recovery-bootstrap of a separate cluster**.
- **Recovery model: to-backup-point only, no PITR.** CNPG's headline doc says
  volumeSnapshot recovery "must reference an external cluster providing the WAL
  archive" — but that applies to _replaying past_ the backup. This cluster has
  no WAL archive/object store; recovery via `backup.name` works only because an
  **online (hot) snapshot retains the WAL segments needed to reach its own
  consistency point inside the snapshot's `pg_wal`** (CNPG holds them via a
  temporary replication slot for the backup's duration). So a restore reaches
  exactly the backup's stop point and cannot go beyond it. This doc tension is
  precisely why **Phase 0 is mandatory** — it proves the in-snapshot WALs
  suffice before we bet prod on it. (Aside: `waitForArchive: true` is set with
  no real archive destination; backups still report `completed` today, but it's
  a latent footgun worth noting.)
- **Databases & role secrets are independent objects.** The 12 app databases are
  separate `Database.postgresql.cnpg.io` CRs (`databaseReclaimPolicy: retain`,
  no ownerRef → survive the Cluster delete) and the 7 `media-pg-*-password`
  Secrets are ArgoCD-managed. The ArgoCD pause protects all of them during the
  window; after recreate they reconcile idempotently against the recovered
  PGDATA. The "capture live spec" step captures only the Cluster object — these
  others must remain in place untouched.
- **No persistent nix-config change needed.** `media-pg.nix` never sets
  `.spec.bootstrap` (relies on CNPG defaulting to initdb). ArgoCD only diffs
  fields present in the desired manifest, so a live `.spec.bootstrap=recovery`
  after an imperative recreate will **not** show as drift and selfHeal will not
  revert it. The entire operation is a runbook + one-time imperative execution.
- **Network policy.** The clusterwide `allow-internal-egress` lets every pod
  reach all in-cluster endpoints (incl. coredns and the CNPG operator), so DNS
  and operator reconciliation work for any new cluster. But `kube-apiserver` is
  a special _entity_, not an endpoint, so egress to it needs an explicit allow.
  The existing `allow-media-pg-apiserver-egress` CNP selects only
  `cnpg.io/cluster=media-pg`. A throwaway `media-pg-verify` therefore needs one
  temporary mirror CNP for apiserver egress. (Phase 1 reuses the name
  `media-pg`, so the existing CNP applies — no temp CNP there.)
- Nothing selects `media-pg-verify` on ingress, so it is not in ingress
  default-deny; the operator's instance-manager calls (8000) are accepted
  without an ingress policy.

## Phase 0 — Non-destructive integrity gate (zero prod impact)

Goal: prove a current snapshot restores to a working Postgres with the real
data, touching nothing in prod. **Gate: do not start Phase 1 unless this
passes.**

```bash
export KUBECONFIG=$HOME/.config/kube/config
NS=media
```

1. **Fresh manual backup** (so we validate a current snapshot):

   ```bash
   cat <<'EOF' | kubectl apply -f -
   apiVersion: postgresql.cnpg.io/v1
   kind: Backup
   metadata: { name: media-pg-predrill, namespace: media }
   spec:
     cluster: { name: media-pg }
     method: volumeSnapshot
   EOF
   # NB: use the FQN backups.postgresql.cnpg.io — longhorn also defines a
   # `Backup` kind, so the `backup` short-name resolves to backups.longhorn.io.
   kubectl -n $NS wait --for=jsonpath='{.status.phase}'=completed \
     backups.postgresql.cnpg.io/media-pg-predrill --timeout=10m
   ```

2. **Temp apiserver-egress CNP** for the verify cluster:

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

3. **Throwaway recovery cluster** from the snapshot:

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

4. **Validate the restore.** Superuser access is **disabled**
   (`enableSuperuserAccess: false`, no superuser secret) — these checks work
   because in-pod `exec` uses local **peer auth** as the `postgres` OS user. Do
   NOT expect a superuser password/secret to exist.

   ```bash
   POD=media-pg-verify-1
   kubectl -n $NS exec $POD -c postgres -- pg_isready
   # databases present (expect sonarr-main/-log, radarr-*, lidarr-*, whisparr-*,
   # prowlarr-*, bazarr, romm):
   kubectl -n $NS exec $POD -c postgres -- psql -U postgres -c '\l'
   # spot-check row counts vs prod on REAL tables (no `|| true` — a missing
   # table MUST fail the gate). sonarr has Series/Episodes; Movies is radarr:
   kubectl -n $NS exec $POD -c postgres -- \
     psql -U postgres -d sonarr-main -tAc 'select count(*) from "Series"'
   kubectl -n $NS exec $POD -c postgres -- \
     psql -U postgres -d radarr-main -tAc 'select count(*) from "Movies"'
   # confirm recovery reached consistency (no FATAL/PANIC in WAL replay):
   kubectl -n $NS logs $POD -c postgres | grep -iE 'consistent recovery|FATAL|PANIC|redo done' | tail
   ```

   Compare the same counts against prod (`media-pg-rw`, same `exec`+peer-auth
   form) to confirm data parity. Any psql error here = **gate fail**.

5. **Tear down** (regardless of outcome):

   ```bash
   kubectl -n $NS delete cluster media-pg-verify
   kubectl -n $NS delete pvc -l cnpg.io/cluster=media-pg-verify
   kubectl -n $NS delete ciliumnetworkpolicy allow-media-pg-verify-apiserver-egress
   # keep media-pg-predrill backup — reuse as the Phase 1 restore source if recent
   ```

6. **GATE.** If validation fails: STOP. We have learned the backup is broken
   without touching prod — capture the failure mode and treat it as an incident.

## Phase 1 — Live one-shot recreate → 1,2 (maintenance window)

Brief media-stack downtime. Order matters.

1. **Pause ArgoCD** (freezes selfHeal fleet-wide so it cannot fight the
   imperative recreate — this is the validated clean-shutdown lever):

   ```bash
   kubectl -n argocd scale statefulset argocd-application-controller --replicas=0
   ```

2. **Quiesce DB clients** (clean disconnect, quiet snapshot). Scale media app
   deployments that hold Postgres connections to 0 (sonarr/radarr/lidarr/
   whisparr/prowlarr/bazarr/romm). Record current replica counts first.

3. **Capture the live cluster spec** (so the recreate keeps every managed role,
   database, backup, monitoring, and anti-affinity setting exactly):

   ```bash
   kubectl -n media get cluster media-pg -o yaml > /tmp/media-pg-current.yaml
   # strip status + runtime metadata (uid, resourceVersion, creationTimestamp,
   # generation, managedFields, .status); add a bootstrap.recovery stanza.
   ```

4. **Fresh cutover backup** (restore source AND fallback). Take a **cold**
   (`online: false`) snapshot: the appendix recommends cold snapshots for
   recovery — a cold snapshot is unambiguously self-contained (no temp-slot WAL
   retention dependency), removing the riskiest variable from the one-shot. The
   clients are already quiesced (step 2), so the fencing cost is near zero.
   (Phase 0 deliberately validated an _online_ snapshot — that proves the actual
   nightly DR story; Phase 1 uses cold purely as belt-and-suspenders for the
   live cutover.)

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
     backups.postgresql.cnpg.io/media-pg-cutover --timeout=10m  # FQN: see Phase 0
   ```

5. **Delete the cluster** (snapshots survive; old PVCs may cascade — fine, we
   restore from the snapshot):

   ```bash
   kubectl -n media delete cluster media-pg
   kubectl -n media delete pvc -l cnpg.io/cluster=media-pg   # ensure clean recreate
   ```

6. **Recreate from recovery** using the captured spec with bootstrap added:

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
   **media-pg-1, media-pg-2**.

7. **Verify:**

   ```bash
   kubectl -n media get cluster media-pg \
     -o jsonpath='phase={.status.phase} ready={.status.readyInstances} primary={.status.currentPrimary} healthy={.status.instancesStatus.healthy}{"\n"}'
   # expect: healthy, ready=2, healthy=[media-pg-1, media-pg-2]
   kubectl -n media get pvc -l cnpg.io/cluster=media-pg   # media-pg-1, media-pg-2
   # Database CRs must re-apply against the recreated cluster:
   kubectl -n media get databases.postgresql.cnpg.io \
     -o custom-columns='NAME:.metadata.name,APPLIED:.status.applied'
   # expect APPLIED=true for all 12
   ```

   Confirm data present (row counts as in Phase 0 step 4, on `media-pg-rw`).
   After ArgoCD re-applies `managed.roles` (step 8), confirm each app role can
   log in (apps reconnect cleanly in step 9) — role passwords come from the
   surviving secrets, not the snapshot.

8. **Re-enable ArgoCD:**

   ```bash
   kubectl -n argocd scale statefulset argocd-application-controller --replicas=1
   # resync the media app; confirm Synced/Healthy. Verify it does NOT try to
   # revert .spec.bootstrap (git never set it).
   ```

9. **Unquiesce apps:** scale media deployments back to recorded counts; confirm
   each connects to `media-pg-rw` and reads its DB.

### Rollback (Phase 1)

At every step before verification succeeds, the snapshots (`media-pg-cutover`
plus the nightly history) are intact. If the recreate fails, re-run step 6
against `media-pg-cutover` (or an earlier nightly). Never delete a snapshot
until the new cluster is verified healthy and serving apps.

## Post-conditions

- `media-pg` recreated as instances 1,2; CNPG dashboard shows 1,2 immediately.
- Stale `media-pg-3` Prometheus series age out on retention.
- Backup restore path proven end-to-end.
- No nix-config change; ArgoCD Synced with `.spec.bootstrap` untouched.
- Runbook reusable as the DR procedure and an extension of the clean-shutdown
  playbook (ArgoCD pause is now documented for cluster maintenance).

## Lessons captured for the playbook

- Deleting a CNPG replica tests streaming re-clone, **not** snapshots; the only
  snapshot test is a recovery-bootstrap of a fresh cluster.
- ArgoCD pause (scale `argocd-application-controller` → 0) is the lever for any
  imperative CNPG surgery on a live cluster.
- A new Cluster object resets instance serials to 1; in-place renumber is
  impossible.
- snapshot-only/in-cluster backups are not disaster recovery — off-cluster
  object store + WAL archiving remains the real DR gap (deferred).
