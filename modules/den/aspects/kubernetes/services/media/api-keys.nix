# Shared *arr API keys for the media stack.
#
# Every Servarr app authenticates the others via a fixed API key (prowlarr →
# the *arrs, the *arrs → sabnzbd/download clients, etc). Rather than let each
# app self-generate a key on first boot (non-reproducible, lost on PVC reset),
# we generate one stable 32-char hex key per app via agenix (`hex-secret`
# generator) and surface them all in a single k8s Secret `media-arr-api-keys`
# (one stringData entry per app). Apps reference their key with
# `env.<APP>__AUTH__APIKEY.valueFrom.secretKeyRef` (key = <app>).
#
# This is a dedicated aspect with its own application (`media-secrets`) so the
# shared Secret isn't coupled to any single app aspect. The Kanidm OIDC client
# secrets live per-app (see _media-app.nix); this file is only the arr API keys.
{ lib, ... }:
let
  # All apps that participate in the shared arr API-key web. Includes the
  # download client (sabnzbd) and the *arrs/prowlarr/bazarr.
  apiKeyApps = [
    "prowlarr"
    "sonarr"
    "radarr"
    "lidarr"
    "whisparr"
    "bazarr"
    "sabnzbd"
  ];

  secretName = "media-arr-api-keys";
in
{
  den.aspects.kubernetes.services.media.api-keys = {
    # One generated 32-char hex key per app, rekeyed into the cluster sops store
    # under the shared `media-arr-api-keys` sops file (key = <app>).
    age-secrets =
      { environment, ... }:
      {
        age.secrets = lib.listToAttrs (
          map (
            app:
            lib.nameValuePair "${secretName}-${app}" {
              rekeyFile = environment.secretPath + "/media-arr-api-keys/${app}.age";
              generator.script = "hex-secret";
              sopsOutput = {
                file = secretName;
                key = app;
              };
            }
          ) apiKeyApps
        );
      };

    k8s-manifests =
      { config, ... }:
      {
        applications.media-secrets = {
          namespace = "media";

          # Shared secrets before the app fleet (wave 0) consumes them.
          annotations."argocd.argoproj.io/sync-wave" = "-1";

          resources.secrets.${secretName} = {
            type = "Opaque";
            # One stringData entry per app; each a sops ref resolved at render
            # time (Secret → SopsSecret via the nixidy objectTransform).
            stringData = lib.listToAttrs (
              map (app: lib.nameValuePair app config.age.secrets."${secretName}-${app}".sopsRef) apiKeyApps
            );
          };
        };
      };
  };
}
