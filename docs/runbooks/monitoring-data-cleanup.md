# Runbook: Monitoring data cleanup (Loki streams · Prometheus series)

**Cluster:** axon k3s · **Namespace:** `monitoring` (data) / `media` (subjects)
**Validated:** 2026-06-14

Force-purge orphaned or high-cardinality observability data instead of waiting
out retention. Use when a label-scheme change or churn leaves **stale streams /
series** behind — e.g. an ephemeral `instance` (pod IP:port) after relabeling to
a stable label, or rotating log `filename` values after switching to a
normalized `log_file`.

**Default posture: do nothing.** Both stores age orphans out at **30d** (loki
`retention_period`, prometheus `retention`/`retentionSize=10GB`). Stale
prometheus series also drop from dashboard dropdowns within each panel's time
window on their own. Only force-purge when you want space or clean dropdowns
_now_.

```bash
export KUBECONFIG=$HOME/.config/kube/config
```

> **Distroless pods.** The loki and prometheus containers have no `wget`/`curl`.
> Always `kubectl port-forward` and run `curl` from your workstation.

---

## GOLDEN RULE — the matcher must be self-bounding, and you DRY-RUN then STOP

A delete matcher must select **only** the orphans and **nothing current**. The
trap: an identifier that looks "obviously stale" can still be the _live_ value
for a target you didn't relabel.

**Procedure for every delete:**

1. Run the matcher against the **read-only series API** first.
2. **STOP and inspect the breakdown** — not just the count. Look at the `job`
   labels (prometheus) or `filename` roots (loki). Confirm every matched series
   belongs to something you expect to be orphaned.
3. Only then issue the delete, as a **separate step**.

Do **not** script dry-run-then-delete in one shot — you will not see the
breakdown before the data is gone.

### Cautionary incident (2026-06-14)

While cleaning stale exporter `instance` series, the matcher
`{job=~"media/.+", instance=~".+:.+"}` was used (intent: "any media exporter
series whose instance is a pod IP is pre-relabel stale"). It also matched
**`media-pg`'s CNPG metrics on `:9187`**, which were _never relabeled_ — so
their **current** instance is colon-form. The delete (no time bound) removed
media-pg's historical metrics. Impact was bounded to monitoring data (media-pg
metrics repopulated from live scrapes; only dashboard history was lost; no
app/DB data, `monitoring-pg` untouched), but it was avoidable. The correct
matcher targets **only the relabeled jobs**:
`{job=~"media/(sonarr|radarr|lidarr|prowlarr|sabnzbd|qbittorrent|unpackerr)", instance=~".+:.+"}`.
Lesson: relabeling is per-PodMonitor — `instance=~colon` is "stale" **only** for
the PodMonitors you actually relabeled; everything else (CNPG
`enablePodMonitor`, kube-state, cilium, …) legitimately uses pod-IP instances.

---

## Loki — purge orphaned log streams

**Prereqs (configured in `monitoring/loki.nix`):**
`compactor.retention_enabled = true`,
`compactor.delete_request_store = "filesystem"`. Single-tenant
(`auth_enabled=false`) → no `X-Scope-OrgID` header needed. **Deletes are
async:** the compactor processes them after `retention_delete_delay` (2h) + its
compaction cycle.

```bash
kubectl -n monitoring port-forward svc/loki 13100:3100   # leave running
end=$(date +%s); start=$((end-2592000))                  # 30d window
MATCH='{namespace="media", filename=~"/config/.+|/home/shoko/.+"}'
```

The example matcher targets the **pre-fix file-tail streams** (their `filename`
started with `/config` or `/home/shoko`). Current file-tail streams dropped the
`filename` label, and live container stdout lives under `/var/log/pods`, so the
matcher is self-bounding. Adjust per incident.

1. **Dry-run + inspect** (confirm only orphans, zero `/var/log`):

   ```bash
   curl -sG http://localhost:13100/loki/api/v1/series \
     --data-urlencode "match[]=$MATCH" \
     --data-urlencode "start=${start}000000000" --data-urlencode "end=${end}000000000" \
     | python3 -c 'import sys,json,collections;d=json.load(sys.stdin);s=d["data"];print("matched:",len(s));print(collections.Counter(x.get("filename","?").split("/")[1] for x in s))'
   ```

   Expect roots `config`/`home` only — **no `var`** (that would be live stdout).

2. **Confirm the delete API is up** (also lists pending requests):

   ```bash
   curl -s http://localhost:13100/loki/api/v1/delete    # HTTP 200 + JSON list = enabled
   ```

3. **Issue the delete:**

   ```bash
   curl -XPOST -G http://localhost:13100/loki/api/v1/delete \
     --data-urlencode "query=$MATCH" \
     --data-urlencode "start=$start" --data-urlencode "end=$end"   # → 204
   ```

4. **Confirm queued:**
   ```bash
   curl -s http://localhost:13100/loki/api/v1/delete   # the request shows status "received"
   ```
   It moves `received → processed` within ~`retention_delete_delay` (2h). Done.

---

## Prometheus — purge series

**Prereq:** the admin TSDB API must be enabled. It is, via
`enableAdminAPI = true` in `monitoring/prometheus.nix`
(`--web.enable-admin-api`). Prometheus has **no external route** — reachable
only in-cluster. The endpoints are **destructive**; there is no time-bounded
variant of `delete_series` unless you pass `start`/`end` (without them it
deletes the series' **entire** history).

```bash
kubectl -n monitoring port-forward pod/prometheus-kube-prometheus-stack-prometheus-0 19090:9090
MATCH='{job=~"media/(sonarr|radarr|lidarr|prowlarr|sabnzbd|qbittorrent|unpackerr)", instance=~".+:.+"}'
```

1. **Confirm the admin API is on:**

   ```bash
   curl -s http://localhost:19090/api/v1/status/flags | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"].get("web.enable-admin-api"))'   # true
   ```

2. **Dry-run + INSPECT THE JOB BREAKDOWN** (the step that prevents the incident
   above):

   ```bash
   curl -sG http://localhost:19090/api/v1/series --data-urlencode "match[]=$MATCH" \
     | python3 -c 'import sys,json,collections;d=json.load(sys.stdin);r=d["data"];print("matched:",len(r));print("by job:",dict(collections.Counter(s.get("job") for s in r)));print("instances:",sorted({s.get("instance") for s in r}))'
   ```

   **STOP.** Every `job` must be one you intended; every `instance` must be a
   genuinely stale value. If a live target appears (e.g. `media/media-pg`),
   tighten the matcher and repeat.

3. **Delete** (optionally add
   `--data-urlencode "start=<unix>" --data-urlencode "end=<unix>"` to bound the
   time range):

   ```bash
   curl -XPOST -G http://localhost:19090/api/v1/admin/tsdb/delete_series \
     --data-urlencode "match[]=$MATCH"    # → 204
   ```

4. **Reclaim space now** (otherwise tombstones clear at the next compaction):

   ```bash
   curl -XPOST http://localhost:19090/api/v1/admin/tsdb/clean_tombstones   # → 204
   ```

5. **Verify** — re-run the step-2 query; deleted series no longer return new
   samples. (The `/series` index may lag until compaction; trust an instant
   query / dashboard over `/series` for "is it gone".) **Note:** deleting a
   series that is still a _live scrape target_ is futile — it reappears on the
   next scrape. Only delete genuinely stale series (no current target produces
   them).

---

## Notes

- **Retention is the safety net.** If a purge is wrong, the over-deletion is
  monitoring data that regenerates (prometheus from live scrapes) or was going
  to expire anyway — but there is **no undo**, so dry-run discipline matters.
- **Why stale `instance`/`filename` happen:** using an ephemeral identifier as
  an indexed label. Fix at the source — relabel `instance` to a stable label
  (PodMonitor `relabelings`), normalize/drop rotating `filename` (Alloy
  `stage.label_drop` + a static `log_file`). See This runbook is for cleaning up
  what already accumulated.
- **Admin API security:** `enableAdminAPI` exposes destructive endpoints to
  anything that can reach prometheus:9090 in-cluster. There is no external
  route; access is operator port-forward + in-cluster queriers (grafana only
  does reads). Disable it again (`enableAdminAPI = false`) if you prefer it off
  between cleanups.
