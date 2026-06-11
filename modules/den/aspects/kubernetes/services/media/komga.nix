# Komga — comics / manga / ebook server.
#
# Simple stateless-ish app built via the mkMediaApp helper: routed +
# OIDC-protected UI on komga.json64.dev (no prod.nix services.komga entry —
# getDomainFor falls back to <name>.<domain> = komga.json64.dev, which the
# Kanidm "komga" client already targets), clientID "komga".
#
# == Storage ==
# Komga keeps its state (an embedded H2/SQLite database, thumbnails cache, search
# index) under /config. We give it a 2Gi longhorn config PVC. The library lives
# on the shared media NFS — comics at /data/media/comics — mounted via the helper's
# mounts.data at /data; the library root is configured in-app (Komga points at
# /data/media/comics). A plain /data mount is sufficient; no subPath gymnastics.
#
# == Auth ==
# Stack convention = Envoy Gateway OIDC only (SecurityPolicy on the HTTPRoute).
# Komga's own user store still exists (it creates an initial admin on first boot);
# we keep gateway OIDC in front and leave Komga's native auth at its default. Komga
# also supports OAuth2/OIDC natively, but we do not wire it (gateway handles it).
#
# == Networking ==
# Helper baseline only: DNS egress + gateway ingress. Base Komga makes minimal
# external calls (cover/metadata enrichment is the separate Komf companion, not
# deployed here), so internetEgress stays false. Add it later if metadata fetching
# is enabled in-app. No postgres (Komga uses its embedded DB under /config).
#
# Version: pinned to the latest stable Komga 1.x release. Bump at deploy time.
{
  config,
  lib,
  ...
}:
let
  media-app = import ./_media-app.nix { inherit lib; };
in
{
  den.aspects.kubernetes.services.media.komga = media-app.mkMediaApp {
    name = "komga";
    port = 25600;
    image = {
      repository = "ghcr.io/gotson/komga";
      tag = "1.24.4";
    };
    inherit (config.den) environments;

    # Komga stores its embedded DB + caches under /config; no postgres.
    postgres = false;

    config-size = "2Gi";

    # Comics library on the shared media NFS at /data/media/comics. The library
    # root is configured in-app; a plain /data mount is enough.
    mounts = {
      data = true;
    };
  };
}
