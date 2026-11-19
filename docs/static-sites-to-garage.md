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
5. **Publishing.**
   - Each site gets its own write key (a GarageKey with write on that bucket
     only, like `sites-publisher`), so a publisher can't touch the landing
     sites.
   - gen-status: `publish-gen-status` changes from rsync to
     `aws s3 sync --delete` against `https://s3.json64.dev`, as `publish-sites`
     does. That change is in den-ag-design, so it's theirs to make. Open
     question 2 covers where their credential comes from.
   - den: a one-time `aws s3 sync` of uplink's `/var/lib/den-docs`, through a
     copy on cortex.

## Rollout

1. Land the buckets, keys and routes with each site's route off (a `live`
   setting per site, as attic and registry had). uplink keeps serving.
2. Upload: den from uplink's copy; gen-status by a publish run (den-ag-design)
   or a one-time copy of uplink's tree.
3. Check each site with `curl --resolve` against the gateway VIP: front page,
   one deep page, a bare-directory URL, the 404, a `/data/` file's headers and
   gzip on `app.js`.
4. Set `live` and remove the three aspects from uplink. Deploy uplink, after
   checking uplink-dev's runner doesn't change.
5. Wipe `/var/lib/den-docs` and `/var/lib/gen-status` from uplink's persist.

Rollback before step 5: unset `live` and re-include the aspects on uplink.

## Open questions for the owner

1. Is den.json64.dev still wanted? It's a hand-copied mirror that hasn't changed
   since 2026-09-29. If den has a published docs site upstream, retire it
   instead of moving it.
2. gen-status's publisher credential. `publish-sites` reads its key from the
   cluster with kubectl. den-ag-design publishes from bitstream or uplink-dev.
   Either the publishing user gets read access to that one Secret, or the key is
   copied into an agenix secret on the publishing host. I'd recommend a kubectl
   role scoped to that single Secret.
3. oauth2-proxy: which UIs does it still front on uplink? It retires with them.
   I haven't enumerated this yet.

## Not covered

Generating den docs from source in CI, and any change to gen-status itself.
