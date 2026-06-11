# Media-stack cutover validation checklist

Operator checklist for bringing the Kubernetes media stack live on `axon` and
cutting over from the old docker-compose deployment. Work top to bottom; each
item lists the command(s) and the expected result.

Legend: `[ ]` = checkbox; ⚠ = requires the user (manual secret entry, image
pins, deploys, drills). Run from a host with kubectl access; postgres history
import uses `scripts/media-migration/import-arr-history.sh`.

---

## 1. Pre-deploy — secrets, dependencies, sync

### 1a. agenix generate / rekey ⚠

All of the following `.age` secrets must be generated and rekeyed before the
manifests render (missing secrets fail the sops bridge). Most are auto-generated
(`agenix generate`); the VPN values are entered by hand.

- [ ] `media-pg` ×7 — postgres role passwords (sonarr, radarr, lidarr, whisparr,
      prowlarr, bazarr, romm). `agenix generate` (rfc3986-secret).
- [ ] `media-arr-api-keys` ×7 — arr API keys (prowlarr, sonarr, radarr, lidarr,
      whisparr, bazarr, sabnzbd). `agenix generate` (hex-secret).
- [ ] `oidc` client secrets ×12 — one per OIDC-protected UI. `agenix generate`
      (rfc3986-secret, tag `oidc`).
- [ ] ⚠ `media-vpn` ×5 — **manual** `agenix edit` with the NEW ProtonVPN
      credentials/config (WireGuard private key, addresses, etc). Do NOT reuse
      the old key — it is revoked at rotation (see teardown).
- [ ] `media-romm` ×1 — romm auth/secret. `agenix generate`.
- [ ] `registry` ×2 — registry credentials. `agenix generate`.

Verify all resolve:

```bash
agenix generate          # generate any missing auto secrets
agenix rekey             # rekey to recipients
git status .secrets/     # confirm new .age files staged
```

- [ ] `convert-oidc-secrets` run (produces the kanidm-consumable client secret
      form). Re-run after any new oidc secret is generated.
- [ ] ⚠ **uplink deploy** — kanidm OAuth2 clients + container registry.
      `colmena apply --on uplink`.
      ⚠ Pre-existing **declarative-jellyfin assertion** on uplink must be
      resolved or worked around FIRST or the deploy fails — track in the
      cutover issue before deploying.
- [ ] ⚠ **axon deploy** — k3s `registries.yaml` (so nodes can pull from the
      private registry) + the scratch aspect on **axon-01** (local-scratch
      PV/dir). `colmena apply --on axon-01` (then the rest of the axon nodes).
- [ ] ⚠ **argo sync** the media namespace apps. After argo picks up the new
      manifests:

```bash
argocd app sync media          # or per-app; or via UI
kubectl get applications -n argocd | grep media
```

Expected: all media Applications reach `Synced` / `Healthy`.

---

## 2. Image tag bump pass ⚠

Every image below is pinned to an archive-era version. Before/at cutover, verify
each tag exists in the registry and bump to the current desired version. Edit
the tag in the listed file, rebuild, re-sync.

| App | Pinned tag | File |
|-----|-----------|------|
| sonarr | `4.0.16` | `services/media/sonarr.nix` |
| radarr | `6.0.4` | `services/media/radarr.nix` |
| lidarr | `2.14.5` | `services/media/lidarr.nix` |
| whisparr | `v2-2.2.0-release.108` | `services/media/whisparr.nix` |
| bazarr | `1.5.6` | `services/media/bazarr.nix` |
| prowlarr | `2.3.0` | `services/media/prowlarr.nix` |
| flaresolverr | `v3.3.21` | `services/media/flaresolverr.nix` |
| sabnzbd | `4.5.3` | `services/media/sabnzbd.nix` |
| qbittorrent | `5.1.2-libtorrentv1` | `services/media/qbittorrent.nix` |
| gluetun | `v3.40.0` | `services/media/qbittorrent.nix` |
| busybox | `1.37.0` | `services/media/qbittorrent.nix` |
| recyclarr | `7.4.1` | `services/media/recyclarr.nix` |
| unpackerr | `0.14.5` | `services/media/unpackerr.nix` |
| glance | `v0.8.4` | `services/media/glance.nix` |
| homepage | `v1.5.0` | `services/media/homepage.nix` |
| romm | `3.10.2` | `services/media/romm.nix` |
| komga | `1.21.2` | `services/media/komga.nix` |

- [ ] Each tag verified present in the registry / upstream.
- [ ] Bumped to current and re-synced.

```bash
# verify a tag exists upstream (example)
skopeo inspect docker://lscr.io/linuxserver/sonarr:4.0.16 >/dev/null && echo ok
# after edits
nix-flake-build axon-01   # or the relevant build target
```

---

## 3. OIDC access control

- [ ] Each UI redirects to kanidm on first hit (unauthenticated → login).

```bash
curl -sI https://sonarr.<domain>/ | grep -i location   # → kanidm authorize URL
```

- [ ] A user in `media.access` can log into the standard apps (sonarr, radarr,
      lidarr, whisparr, bazarr, jellyfin, etc).
- [ ] A non-member is **403** (forbidden) on those apps.
- [ ] Admin-only apps (prowlarr, sabnzbd/nzb, qbittorrent/torrent) require
      `media.admins`; a `media.access`-only user is 403 on them.

---

## 4. Storage / scheduling

- [ ] PVCs bound:

```bash
kubectl get pvc -n media        # all Bound
```

- [ ] `media-scratch-local` is bound on **axon-01** (local-scratch).
- [ ] NFS PVs (`media-data-nfs`, `media-scratch-nfs`) bound.
- [ ] Scratch-bound pods (sabnzbd, qbittorrent, unpackerr) scheduled on
      **axon-01** (where local-scratch lives):

```bash
kubectl get pods -n media -o wide | grep -E 'sabnzbd|qbittorrent|unpackerr'
```

- [ ] arr pods are **not** node-pinned (can run anywhere):

```bash
kubectl get pods -n media -o wide | grep -E 'sonarr|radarr|lidarr|whisparr|prowlarr'
```

---

## 5. CNPG postgres (media-pg)

- [ ] Cluster healthy:

```bash
kubectl cnpg status media-pg -n media     # 2/2 instances, primary + replica
```

- [ ] Databases present:

```bash
kubectl exec media-pg-1 -n media -c postgres -- psql -U postgres -lqt | cut -d'|' -f1
# expect: sonarr-main sonarr-log radarr-main radarr-log lidarr-main lidarr-log
#         whisparr-main whisparr-log prowlarr-main prowlarr-log bazarr romm
```

- [ ] Nightly ScheduledBackup fires and a VolumeSnapshot exists:

```bash
kubectl get scheduledbackup -n media
kubectl get backup -n media
kubectl get volumesnapshot -n media      # one per nightly run
```

---

## 6. Usenet path end-to-end

- [ ] Trigger a grab in sonarr → it queues in sabnzbd.
- [ ] Download lands on the **NVMe scratch** (local-scratch on axon-01) — verify
      on the node:

```bash
ssh axon-01 'ls -la /var/lib/media-scratch/...'   # path per scratch aspect
```

- [ ] unpackerr/import copies into `/data/media/tv` (NFS).
- [ ] jellyfin sees the new item (library scan picks it up).

---

## 7. Torrent path + VPN kill-switch

- [ ] gluetun public IP ≠ home IP:

```bash
kubectl exec deploy/qbittorrent -n media -c gluetun -- wget -qO- https://api.ipify.org
# compare against home WAN IP — MUST differ
```

- [ ] Forwarded port is set in qbittorrent prefs (port-sync sidecar):

```bash
kubectl logs deploy/qbittorrent -n media -c <port-sync-container> | tail
# qbt listen port updated to gluetun's forwarded port
```

- [ ] Grab → seed → import works through the torrent client.
- [ ] ⚠ **Kill-switch drill**: stop the gluetun container; qbittorrent egress
      must drop (no traffic leaks):

```bash
# stop gluetun (e.g. kill its process / scale-edit), then:
kubectl exec deploy/qbittorrent -n media -c qbittorrent -- wget -T5 -qO- https://api.ipify.org
# expect TIMEOUT / failure (no egress without the VPN)
hubble observe -n media --pod qbittorrent --verdict DROPPED | tail
```

Restore gluetun afterwards.

---

## 8. Cilium network policy

- [ ] No legitimate flows are being dropped:

```bash
hubble observe -n media --verdict DROPPED --last 200
# only expected denials (e.g. kill-switch drill), no normal app traffic
```

- [ ] Dashboard widgets populate (CiliumNetworkPolicy edges live in the
      topology view).

---

## 9. History import

Run the importer once per app from a host with kubectl context. It scales the
app down, pgloads its SQLite history into `<app>-main` (data-only + truncate,
**excluding** the VersionInfo migration table), then scales back up.

⚠ Pin `PGLOADER_IMAGE` to a digest in the script before running (reproducibility).

```bash
for app in sonarr radarr lidarr whisparr prowlarr; do
  ./scripts/media-migration/import-arr-history.sh "$app"
done
```

- [ ] sonarr — UI History shows imported records.
- [ ] radarr — UI History shows imported records.
- [ ] lidarr — UI History shows imported records.
- [ ] whisparr — UI History shows imported records (note: file is `whisparr2.db`).
- [ ] prowlarr — UI History shows imported records.

If pgloader fails on missing columns, the running image is on a different
migration level than the archive db — see the VERSION SKEW remedy printed by the
script (pin to archive-era image, boot, re-run, bump).

---

## 10. Registry round-trip

- [ ] podman login + push a test image + pull it from a pod:

```bash
podman login registry.<domain>
podman tag busybox:1.37.0 registry.<domain>/test/busybox:probe
podman push registry.<domain>/test/busybox:probe
kubectl run reg-pull-test -n media --rm -it --restart=Never \
  --image=registry.<domain>/test/busybox:probe -- true   # pulls + exits 0
```

---

## 11. Scratch-node drain drill ⚠

Verify graceful degradation when axon-01 (scratch node) is unavailable.

- [ ] Cordon + drain axon-01 briefly:

```bash
kubectl cordon axon-01
kubectl drain axon-01 --ignore-daemonsets --delete-emptydir-data --force
```

- [ ] arr pods stay **Running** (imports stall, that is expected).
- [ ] downloaders (sabnzbd/qbittorrent/unpackerr) go **Pending** (they need
      local-scratch on axon-01).

```bash
kubectl get pods -n media -o wide
```

- [ ] Uncordon → everything recovers:

```bash
kubectl uncordon axon-01
kubectl get pods -n media -o wide   # downloaders schedule back on axon-01
```

---

## 12. Teardown / cleanup

- [ ] Old ProtonVPN key revoked (done at rotation when `media-vpn` was
      re-entered — confirm it is actually revoked upstream).
- [ ] `scripts/media-migration/` deleted from the repo post-cutover (one-shot
      tooling; remove once history import is verified):

```bash
git rm -r scripts/media-migration && git commit -m "chore(media): remove one-shot migration tooling post-cutover"
```

- [ ] Old archive at `/mnt/data/media-user-backup` retained until the operator
      is confident, then deleted manually.
- [ ] Memory files updated (cutover complete; record any deviations).
