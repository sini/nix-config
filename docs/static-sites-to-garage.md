# Plan: uplink's static sites to Garage website buckets

Status: draft for the owner, 2026-11-19. Part of the uplink plan
(docs/uplink-maintenance-plan.md, Tier 2 item 11).

## Summary

Move den.json64.dev (den-docs-mirror) and gen-status.json64.dev off uplink's
nginx into Garage website buckets, served by the cluster gateway. The landing
sites already work this way (kubernetes/services/storage/garage/sites.nix), so
this extends that aspect to subdomain sites rather than building anything new.
Retire uplink's homepage (it already runs in the cluster) in the same change.

## What runs today (measured 2026-11-19)

| Site                  | Size, files     | Written by                                                                                                                | nginx behaviour it relies on                                                                                                    |
| --------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| den.json64.dev        | 19 MB, 137 html | nobody: hand-copied, unchanged since 2026-09-29; no publisher in any repo                                                 | `try_files $uri $uri/index.html $uri.html`; 2 pages are bare `.html` (tools/ir-viewer.html), linked by full name                |
| gen-status.json64.dev | 43 MB, 3533     | den-ag-design's `publish-gen-status` (ci/devshell.nix): `rsync --delete --delay-updates` to `uplink:/var/lib/gen-status/` | `gzip_static` for 5 pre-gzipped files (index, app.js, styles); `Cache-Control: public, max-age=60, must-revalidate` on `/data/` |

Both are public, with no auth.

## Design

1. **Buckets.** sites.nix takes its domains from the `site-domains` quirk, which
   only the landing domains emit (`web.landing`, modules/den/domains). A record
   gains an optional `apex` (default true). The two subdomain sites are emitted
   by a new cluster aspect, `kubernetes.services.web.static-sites`, one record
   each with `apex = false`. Each gets a GarageBucket named after its domain
   (`globalAlias = domain`, website on, `index.html` and `404.html`), as today.
2. **Routes.** A non-apex site routes on the domain's `-https` listener, not
   `-apex-https`, and gets no `www.` redirect. Backend: Garage's web endpoint
   (:3902), which picks the bucket from the Host header. Garage's network policy
   already admits the gateways to 3902.
3. **DNS.** The new aspect emits `served-domains` (unproxied, like attic) for
   `den-docs-mirror` and `gen-status`. uplink drops
   `services.web.den-docs-mirror`, `services.web.gen-status` and
   `services.web.homepage`, so the names move from uplink's TLS passthrough to
   the cluster gateway in one sync.
4. **nginx parity.**
   - Directory index: Garage serves `foo/index.html` for `foo/`. Check that a
     bare `/foo` still resolves (Garage redirects to the trailing slash when the
     index exists); the verification step tests it on a den page.
   - `$uri.html` fallback: dropped. Nothing found in the content relies on it;
     the two bare-`.html` pages are linked by full name.
   - gzip: the gateway compresses responses (a BackendTrafficPolicy
     `compression` on the site routes) instead of `gzip_static`. The `.gz` files
     can stop being published.
   - `Cache-Control` on gen-status `/data/`: an HTTPRoute rule for the `/data/`
     prefix with a `ResponseHeaderModifier`, so it doesn't depend on Garage
     returning stored object metadata.
5. **Publishing.** Each site has its own write key, with write on that bucket
   only, so a publisher can't touch the other sites. den is a one-time upload
   from cortex; gen-status is published repeatedly by den-ag-design, which needs
   the coordination below.

### gen-status's publisher credential

The key is generated once in nix-config and delivered to both sides, so nobody
copies it by hand and no publishing host needs cluster access.

1. **One source.** Two agenix secrets in the prod environment's secrets:
   - `gen-status-publisher-key-id`: `GK` plus 24 hex characters;
   - `gen-status-publisher-secret`: 64 hex characters.

   That's Garage's key format; v2.4.1 accepts any format, but this one is safe
   across versions. A new generator script, `garage-key`, makes both.

2. **Into the cluster.** Both secrets have a `sopsOutput`, so a SopsSecret
   renders them into a Secret in the garage namespace. The publisher's GarageKey
   imports them (`spec.importKey.secretRef`) instead of minting its own, with
   write on the gen-status bucket only. The operator registers that exact key
   with Garage.
3. **Onto the publishing hosts.** A host aspect,
   `services.web.gen-status-publisher`, makes the host a recipient of the same
   two rekeyFiles (the shared-secret pattern registry-password uses) and renders
   one env file from them:
   - path: `/run/agenix/gen-status-publish.env`, owned by sini, mode 0400;
   - contents: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
     `AWS_DEFAULT_REGION=garage` and
     `GEN_STATUS_S3_ENDPOINT=https://s3.json64.dev`.

   It goes on bitstream and uplink-dev, where den-ag-design's sessions run.
   uplink-dev is a guest, so the deploy that adds the aspect changes its runner
   and restarts it: it waits for den-ag-design's stopping point, as every
   uplink-dev restart does.

4. **The publish command** (den-ag-design's change, ci/devshell.nix): keep the
   build and its self-check, then replace the rsync with

       set -a; . /run/agenix/gen-status-publish.env; set +a
       aws s3 sync --delete "$out_dir/" s3://gen-status.json64.dev/ \
         --endpoint-url "$GEN_STATUS_S3_ENDPOINT"

   It fails if the env file is missing, so a session on a host without the
   aspect gets a clear error rather than a partial publish. The spec's D2 ruling
   ("manual rsync to uplink") is amended to match; that edit is den-ag-design's.

5. **The agent's handling.** The publishing agent runs as sini and needs only to
   source the file. It never prints or copies the credentials: the command
   sources the file in its own shell, and nothing echoes them. I'll give
   den-ag-design that rule, together with the path, the bucket, the endpoint and
   the command, in one message when step 3 is deployed.
6. **Rotation.** Regenerate the two agenix secrets, `agenix sops-rekey`, push,
   then deploy bitstream and uplink-dev. Until both sides have the new key,
   publishing fails with 403, and nothing is half-written, because the sync
   fails at its first request.

## Rollout

1. **Land the plumbing.**
   - Buckets, keys and routes go in with each site's route off: a `live` setting
     per site, as attic and registry had. uplink keeps serving.
   - The publisher secrets and the `gen-status-publisher` aspect land too.
     Deploy bitstream, and uplink-dev at its next agreed restart.
2. **Hand over the publisher** to den-ag-design (step 5 above). They change
   `publish-gen-status` and run it once. The first run fills the bucket while
   uplink still serves the site.
3. **Upload den** from cortex: copy uplink's `/var/lib/den-docs` to cortex with
   `rsync`, then `aws s3 sync` it with den's key, read from the cluster as
   `publish-sites` does.
4. **Check each site** with `curl --resolve` against the gateway VIP:
   - the front page and one deep page;
   - a bare-directory URL;
   - the 404 page;
   - the headers of a `/data/` file;
   - gzip on `app.js`.
5. **Cut over.** Set `live` and remove the three aspects from uplink. Deploy
   uplink, after checking uplink-dev's runner doesn't change.
6. **Clean up.** Wipe `/var/lib/den-docs` and `/var/lib/gen-status` from
   uplink's persist.

Rollback before step 6: unset `live` and re-include the aspects on uplink. Until
den-ag-design's command changes, its old rsync keeps working, because uplink
still serves.

## Decided (owner, 2026-11-19)

- den.json64.dev moves.
- The gen-status publisher gets its key from nix-config, as above.
- oauth2-proxy retires. On uplink it fronts only uplink's homepage (blocky-ui
  moved to the cluster), so it goes with it: the aspect, its kanidm OAuth2
  client `oauth2-proxy` and its secrets.
- uplink's homepage is homepage.json64.dev; the cluster's dashboard is a
  different one, dash.json64.dev. The gateway 301s homepage.json64.dev to
  dash.json64.dev, so links keep working.

## Not covered

Generating den docs from source in CI, and any change to gen-status itself.
