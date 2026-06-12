#!/usr/bin/env bash
#
# import-arr-history.sh — one-shot migration of a Servarr app's SQLite history
# into its CloudNativePG (media-pg) postgres database.
#
# This is operator tooling, run ONCE per app at media-stack cutover from the
# host's kubectl context. It is NOT wired into any deploy and lives only under
# scripts/media-migration/ until cutover is verified, then the whole directory
# is deleted (see VALIDATION.md, teardown).
#
# What it does, per app:
#   1. Preflight: the Deployment exists and has booted at least once against
#      postgres (the Servarr migration table "VersionInfo" is present in the
#      <app>-main database).
#   2. Prints a version-skew warning (image tag vs the archive-era version) so
#      the operator can pin the image down if the SQLite schema is ahead of /
#      behind the running app's migration level.
#   3. Scales the Deployment to 0 (no writers while we copy).
#   4. Runs pgloader as a one-shot k8s Job in the `media` namespace. pgloader
#      reads the app's SQLite db from the NAS archive (mounted read-only via the
#      media-data-nfs PVC) and copies it into <app>-main over the network to
#      media-pg-rw. The copy is DATA ONLY with TRUNCATE so re-runs are
#      idempotent, and EXCLUDES the VersionInfo table so the fresh-boot
#      migration level is preserved (clobbering it with the archive's migration
#      numbers would corrupt the app's schema-version bookkeeping — this is the
#      procedure documented in the Servarr wiki).
#   5. Waits for the Job, dumps its logs, deletes it on success (kept on
#      failure for inspection).
#   6. Scales the Deployment back to 1 and reminds the operator to verify the
#      UI history.
#
# Idempotent: re-running re-truncates and re-copies. Safe to retry on failure.
#
# Usage:
#   ./import-arr-history.sh <app>      # app ∈ {sonarr radarr lidarr whisparr prowlarr}
#
set -euo pipefail

# --------------------------------------------------------------------------- #
# Tunables                                                                     #
# --------------------------------------------------------------------------- #

NAMESPACE="media"

# CNPG primary (read-write) service inside the cluster. media-pg.nix declares a
# 2-instance Cluster named "media-pg"; CNPG publishes media-pg-rw for the
# primary. We reference it FQDN-style from inside the namespace.
PG_RW_HOST="media-pg-rw.media.svc"
PG_PORT="5432"

# A CNPG instance pod we can exec psql in for preflight checks. CNPG names
# instance pods <cluster>-1, <cluster>-2; -1 is the bootstrap primary. The
# psql client and the postgres superuser socket live in the "postgres"
# container.
PG_POD="media-pg-1"
PG_CONTAINER="postgres"

# pgloader image. Pin to a digest at RUN TIME for reproducibility — replace the
# :latest tag below with the digest you pull, e.g.
#   ghcr.io/dimitri/pgloader@sha256:<digest>
# (flagged here deliberately; the operator pins when they run this.)
PGLOADER_IMAGE="ghcr.io/dimitri/pgloader:latest"

# Where the media-data-nfs PVC (NAS /volume2/data) is mounted inside the Job.
# ARCHIVE PATH ASSUMPTION:
#   On the workstation the NAS share /volume2/data is mounted at /mnt/data, and
#   the archive lives at /mnt/data/media-user-backup. The media-data-nfs PV
#   exports that same NAS share root (/volume2/data), so inside the PV the
#   archive is at /media-user-backup/... — i.e. WITHOUT the /mnt/data prefix.
# We mount the PVC at /backup-root, so the in-Job sqlite path is:
#   /backup-root/media-user-backup/configs/<app>/<file>.db
# A Job-level `test -f` guards this assumption before pgloader runs.
BACKUP_MOUNT="/backup-root"
ARCHIVE_SUBPATH="media-user-backup/configs"

# --------------------------------------------------------------------------- #
# Per-app constants                                                            #
# --------------------------------------------------------------------------- #
#
# Columns:
#   deployment   k8s Deployment name (== app name; see _media-app.nix)
#   sqlite_file  filename of the main SQLite db in the archive config dir
#   main_db      target postgres database (<app>-main per media-pg.nix)
#   pg_role      postgres login role / sqlite owner (== app name)
#   pg_secret    k8s basic-auth Secret holding the role password
#   archive_ver  version found in the media-user-backup logs (for skew warning)
#
# NOTE the whisparr SQLite file is "whisparr2.db" (v2/whisparr2 line), NOT
# "whisparr.db" — verified against the archive.

app_deployment() { echo "$1"; }                       # deployment == app name
app_pg_role()    { echo "$1"; }                       # role == app name
app_main_db()    { echo "$1-main"; }                  # <app>-main per media-pg.nix
app_pg_secret()  { echo "media-pg-$1-password"; }     # basic-auth secret

app_sqlite_file() {
  case "$1" in
    sonarr)   echo "sonarr.db" ;;
    radarr)   echo "radarr.db" ;;
    lidarr)   echo "lidarr.db" ;;
    whisparr) echo "whisparr2.db" ;;   # v2 line — file is whisparr2.db
    prowlarr) echo "prowlarr.db" ;;
    *) return 1 ;;
  esac
}

app_archive_version() {
  # Informational only (drives the skew warning). Update if the archive notes
  # change. "unknown" is fine — it just makes the warning generic.
  case "$1" in
    sonarr)   echo "4.0.16.x (v4 era)" ;;
    radarr)   echo "v5/v6 era" ;;
    lidarr)   echo "v2 era" ;;
    whisparr) echo "v2 (whisparr2)" ;;
    prowlarr) echo "v1/v2 era" ;;
    *) echo "unknown" ;;
  esac
}

# --------------------------------------------------------------------------- #
# Helpers                                                                      #
# --------------------------------------------------------------------------- #

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo ">>> $*"; }
warn() { echo "!!! $*" >&2; }

usage() {
  cat >&2 <<EOF
Usage: $0 <app>

  app   one of: sonarr radarr lidarr whisparr prowlarr

Migrates the named app's SQLite history into its media-pg <app>-main database
via a one-shot pgloader Job. Run from a host with kubectl access to the cluster.
EOF
  exit 2
}

# --------------------------------------------------------------------------- #
# Argument parsing                                                             #
# --------------------------------------------------------------------------- #

[ $# -eq 1 ] || usage
APP="$1"

case "$APP" in
  sonarr|radarr|lidarr|whisparr|prowlarr) ;;
  *) warn "unknown app: $APP"; usage ;;
esac

DEPLOY="$(app_deployment "$APP")"
SQLITE_FILE="$(app_sqlite_file "$APP")" || die "no sqlite file mapping for $APP"
MAIN_DB="$(app_main_db "$APP")"
PG_ROLE="$(app_pg_role "$APP")"
PG_SECRET="$(app_pg_secret "$APP")"
ARCHIVE_VER="$(app_archive_version "$APP")"

# In-PV (in-Job) absolute path to the SQLite db.
SQLITE_IN_JOB="${BACKUP_MOUNT}/${ARCHIVE_SUBPATH}/${APP}/${SQLITE_FILE}"

JOB_NAME="pgloader-import-${APP}"

info "app=${APP} deploy=${DEPLOY} db=${MAIN_DB} role=${PG_ROLE}"
info "sqlite (in-job): ${SQLITE_IN_JOB}"

# --------------------------------------------------------------------------- #
# Step 1 — preflight: deployment exists + schema present                       #
# --------------------------------------------------------------------------- #

info "Preflight: checking Deployment ${DEPLOY} exists in ${NAMESPACE}..."
kubectl get deploy "${DEPLOY}" -n "${NAMESPACE}" >/dev/null 2>&1 \
  || die "Deployment ${DEPLOY} not found in namespace ${NAMESPACE}. Deploy the app first."

info "Preflight: checking ${MAIN_DB} has Servarr schema (VersionInfo present)..."
# The app must have booted at least once against postgres so CNPG/the app has
# created the schema. We query the Servarr migration table "VersionInfo".
# psql -t -A => tuples only, unaligned (bare number). Quoting "VersionInfo"
# preserves the mixed case (Servarr creates a capitalised table name).
VERSION_COUNT="$(
  kubectl exec "${PG_POD}" -n "${NAMESPACE}" -c "${PG_CONTAINER}" -- \
    psql -U postgres -d "${MAIN_DB}" -tAc \
    'select count(*) from "VersionInfo"' 2>/dev/null
)" || die "Could not query \"VersionInfo\" in ${MAIN_DB}. \
Has ${APP} booted at least once against postgres? (Schema must exist before import.)"

info "Preflight OK: VersionInfo rows = ${VERSION_COUNT}"

# --------------------------------------------------------------------------- #
# Step 2 — version-skew warning                                                #
# --------------------------------------------------------------------------- #

CURRENT_TAG="$(
  kubectl get deploy "${DEPLOY}" -n "${NAMESPACE}" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true
)"

cat >&2 <<EOF

------------------------------------------------------------------------------
VERSION SKEW CHECK (${APP})
  Running image : ${CURRENT_TAG:-<unknown>}
  Archive era   : ${ARCHIVE_VER}

The SQLite schema must match the migration level of the RUNNING app. If pgloader
later fails with errors about missing columns / tables, the running app is on a
DIFFERENT migration level than the archive db.

  Remedy (manual — this script does NOT automate it):
    1. Pin the Deployment image to the archive-era version, e.g.
         kubectl set image deploy/${DEPLOY} -n ${NAMESPACE} \\
           main=<archive-era-image>:<tag>
    2. Let it boot once (rollout status) so it migrates the EMPTY postgres db to
       the archive's migration level, then scale to 0.
    3. Re-run this script.
    4. After a successful import, bump the image back to the target version and
       let the app migrate postgres forward (it migrates the imported data).
------------------------------------------------------------------------------

EOF

# --------------------------------------------------------------------------- #
# Step 3 — scale deployment down                                              #
# --------------------------------------------------------------------------- #

info "Scaling ${DEPLOY} to 0 replicas (no writers during copy)..."
kubectl scale deploy/"${DEPLOY}" -n "${NAMESPACE}" --replicas=0
kubectl rollout status deploy/"${DEPLOY}" -n "${NAMESPACE}" --timeout=120s || true
# Belt-and-suspenders: wait for pods to actually be gone.
info "Waiting for ${DEPLOY} pods to terminate..."
kubectl wait --for=delete pod \
  -l app.kubernetes.io/name="${APP}" -n "${NAMESPACE}" --timeout=120s 2>/dev/null || true

# --------------------------------------------------------------------------- #
# Step 4/7 — run pgloader as a one-shot Job                                    #
# --------------------------------------------------------------------------- #
#
# We use a pgloader COMMAND FILE (not bare CLI args) because we must EXCLUDE the
# VersionInfo table — the `EXCLUDING TABLE NAMES LIKE` clause is only
# available in the load-command-file form. The command file is written into the
# Job container via a heredoc in `sh -c`, then pgloader runs it.
#
# Command-file options:
#   data only        — copy rows only; do NOT recreate tables (fresh boot made
#                      them with the correct postgres types already).
#   truncate         — TRUNCATE each target table before copy → idempotent reruns.
#   quote identifiers— preserve Servarr's CamelCase table/column names.
#   EXCLUDING TABLE NAMES LIKE 'VersionInfo'
#                    — do NOT touch the migration table; the fresh-boot value
#                      stays authoritative (Servarr-wiki procedure).
#
# The logs db (<app>-log) is intentionally NOT imported — fresh logs are fine.
#
# Pre-pgloader guard: `test -f` the sqlite path so a wrong archive-path
# assumption fails loudly with a clear message instead of a confusing pgloader
# error.

# Clean any stale Job from a previous run (idempotency).
info "Removing any previous ${JOB_NAME} Job..."
kubectl delete job "${JOB_NAME}" -n "${NAMESPACE}" --ignore-not-found

info "Creating pgloader Job ${JOB_NAME}..."

# Note on PGPASSWORD: pgloader reads the postgres password from the connection
# string OR the PGPASSWORD env var. We pass the role password from the k8s
# basic-auth Secret (key "password") via valueFrom, and leave it out of the
# pgsql:// URI so it never appears in logs.

kubectl apply -n "${NAMESPACE}" -f - <<MANIFEST
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: pgloader-import
    media-migration/app: ${APP}
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app.kubernetes.io/name: pgloader-import
        media-migration/app: ${APP}
    spec:
      restartPolicy: Never
      volumes:
        - name: backup
          persistentVolumeClaim:
            claimName: media-data-nfs
            readOnly: true
      containers:
        - name: pgloader
          image: ${PGLOADER_IMAGE}
          env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${PG_SECRET}
                  key: password
          volumeMounts:
            - name: backup
              mountPath: ${BACKUP_MOUNT}
              readOnly: true
          command:
            - /bin/sh
            - -c
            - |
              set -eu

              # --- archive-path guard ------------------------------------
              if [ ! -f "${SQLITE_IN_JOB}" ]; then
                echo "FATAL: sqlite db not found at ${SQLITE_IN_JOB}" >&2
                echo "Listing ${BACKUP_MOUNT}/${ARCHIVE_SUBPATH}/${APP}:" >&2
                ls -la "${BACKUP_MOUNT}/${ARCHIVE_SUBPATH}/${APP}" >&2 || true
                exit 1
              fi
              echo "Found sqlite db: ${SQLITE_IN_JOB}"

              # --- local writable copy -----------------------------------
              # WAL-mode sqlite cannot be opened on the read-only NFS mount
              # (the open needs to create/lock the -shm next to the file);
              # pgloader then logs an ERROR but still exits 0 with an empty
              # load. Copy db + journal files to the writable /tmp and load
              # from there (sqlite recovers/replays the WAL on the copy, so
              # un-checkpointed writes are preserved).
              cp "${SQLITE_IN_JOB}" /tmp/source.db
              for sfx in wal shm; do
                if [ -f "${SQLITE_IN_JOB}-\${sfx}" ]; then
                  cp "${SQLITE_IN_JOB}-\${sfx}" "/tmp/source.db-\${sfx}"
                fi
              done

              # --- write pgloader command file ---------------------------
              # Written with printf (not a nested heredoc) so we don't depend on
              # the in-pod /bin/sh finding an indented heredoc terminator. The
              # shell placeholders below were already substituted by the
              # operator shell when this manifest was rendered, so they are
              # literal values here.
              printf '%s\n' \
                'LOAD DATABASE' \
                '  FROM sqlite:///tmp/source.db' \
                '  INTO pgsql://${PG_ROLE}@${PG_RW_HOST}:${PG_PORT}/${MAIN_DB}' \
                '' \
                'WITH data only,' \
                '     truncate,' \
                '     reset no sequences,' \
                '     quote identifiers,' \
                '     workers = 2, concurrency = 1,' \
                '     prefetch rows = 10000, batch rows = 5000' \
                '' \
                "EXCLUDING TABLE NAMES LIKE 'VersionInfo'" \
                ';' \
                > /tmp/load.cmd

              echo "----- pgloader command file -----"
              cat /tmp/load.cmd
              echo "---------------------------------"

              exec pgloader --on-error-stop /tmp/load.cmd
MANIFEST

# --------------------------------------------------------------------------- #
# Step 6 — wait for the Job, dump logs                                         #
# --------------------------------------------------------------------------- #

info "Waiting for Job ${JOB_NAME} to finish (timeout 30m)..."
# Wait for either complete or failed. `kubectl wait` can only watch one
# condition, so we race both in the background and take whichever fires.
set +e
kubectl wait --for=condition=complete "job/${JOB_NAME}" -n "${NAMESPACE}" --timeout=1800s
COMPLETE_RC=$?
set -e

# Always dump logs.
info "----- pgloader Job logs -----"
kubectl logs "job/${JOB_NAME}" -n "${NAMESPACE}" || true
info "-----------------------------"

if [ "${COMPLETE_RC}" -ne 0 ]; then
  # Not complete — check if it failed explicitly.
  if kubectl get job "${JOB_NAME}" -n "${NAMESPACE}" \
       -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null \
       | grep -qi true; then
    warn "pgloader Job FAILED. Job kept for inspection: kubectl describe job/${JOB_NAME} -n ${NAMESPACE}"
  else
    warn "pgloader Job did not report complete within timeout. Job kept for inspection."
  fi
  warn "NOTE: ${DEPLOY} is still scaled to 0. Investigate, then re-run this script."
  exit 1
fi

info "pgloader Job completed. Deleting Job..."
kubectl delete job "${JOB_NAME}" -n "${NAMESPACE}" --ignore-not-found

# --------------------------------------------------------------------------- #
# Step 7b — reset sequences (pgloader's own reset has a CamelCase quoting bug: #
# it passes quote_ident(attname) to pg_get_serial_sequence, which wants the    #
# bare column name, so every "Id" column errors. Done here correctly instead;  #
# the Job runs WITH reset no sequences.)                                       #
# --------------------------------------------------------------------------- #

info "Resetting sequences in ${MAIN_DB}..."
kubectl exec "${PG_POD}" -n "${NAMESPACE}" -c "${PG_CONTAINER}" -- \
  psql -U postgres -d "${MAIN_DB}" -v ON_ERROR_STOP=1 -c "
DO \$\$
DECLARE r record; n int := 0;
BEGIN
  FOR r IN
    SELECT n.nspname, c.relname, a.attname,
           pg_get_serial_sequence(format('%I.%I', n.nspname, c.relname), a.attname) AS seq
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid
    JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef
    WHERE c.relkind = 'r' AND a.attnum > 0
      AND pg_get_expr(d.adbin, d.adrelid) ~ '^nextval'
      AND n.nspname = 'public'
  LOOP
    EXECUTE format('SELECT setval(%L, GREATEST((SELECT COALESCE(MAX(%I), 1) FROM ONLY %I.%I), 1))',
                   r.seq, r.attname, r.nspname, r.relname);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'sequences reset: %', n;
END \$\$;"

# --------------------------------------------------------------------------- #
# Step 8 — scale deployment back up                                            #
# --------------------------------------------------------------------------- #

info "Scaling ${DEPLOY} back to 1 replica..."
kubectl scale deploy/"${DEPLOY}" -n "${NAMESPACE}" --replicas=1
kubectl rollout status deploy/"${DEPLOY}" -n "${NAMESPACE}" --timeout=300s

cat >&2 <<EOF

==============================================================================
DONE — ${APP} history imported into ${MAIN_DB}.

  NEXT (manual):
    * Open the ${APP} UI and verify the Activity / History view shows the
      imported records (counts should match the old instance).
    * If the UI shows schema errors, see the VERSION SKEW remedy above.
==============================================================================
EOF
