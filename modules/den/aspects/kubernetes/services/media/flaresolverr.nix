# FlareSolverr — proxy that solves Cloudflare/JS challenges for the indexers.
#
# Stateless: no config PVC, no route, no OIDC. Reached in-cluster by Prowlarr
# (a FlareSolverr "indexer proxy") on its API port. It must reach the public
# internet (that is its entire job), so it gets a world-egress CNP on 80/443.
{ config, lib, ... }:
let
  media-app = import ./_media-app.nix { inherit lib; };
in
{
  den.aspects.kubernetes.services.media.flaresolverr = media-app.mkMediaApp {
    name = "flaresolverr";
    port = 8191;
    image = {
      repository = "ghcr.io/flaresolverr/flaresolverr";
      tag = "v3.3.21";
    };
    inherit (config.den) environments;

    route = false;
    oidc = false;
    config-size = null;
    internetEgress = true;

    env.LOG_LEVEL = "info";
  };
}
