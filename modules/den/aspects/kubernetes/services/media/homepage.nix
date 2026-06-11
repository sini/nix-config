# Homepage (gethomepage) — the utility dashboard for the media stack.
#
# == Naming: "dash", not "homepage" ==
# The uplink host already runs a NixOS homepage-dashboard on homepage.json64.dev
# (modules/den/aspects/services/web/homepage.nix, behind oauth2-proxy) and owns
# service-domains "homepage". To avoid a hard domain collision this k8s dashboard
# is named "dash" -> dash.json64.dev (prod.nix services.dash.domain). The Kanidm
# OAuth2 client is "dash" too (kanidm.nix mediaClientDefs.dash), so clientID =
# "dash" and the helper's getDomainFor "dash" + OIDC contract line up.
#
# == Chart vs raw ==
# nixhelm carries no gethomepage chart, so this is mkMediaApp on the upstream
# image (ghcr.io/gethomepage/homepage) with config + RBAC layered via extraValues
# and an aspect post-merge (the qbittorrent.nix pattern).
#
# == Config (static, deterministic) ==
# Homepage reads /app/config/{settings,services,widgets,bookmarks,kubernetes}.yaml.
# We deliver them as one ConfigMap mounted file-by-file via subPath. We use a
# STATIC services.yaml (not HTTPRoute/ingress auto-discovery): gateway-api
# HTTPRoute discovery is newer/less battle-tested, and a static list is fully
# deterministic with no annotation sprawl. Service widgets pull *arr/sabnzbd API
# keys via {{HOMEPAGE_VAR_*}} substitution backed by env from media-arr-api-keys.
# kubernetes.yaml mode=cluster surfaces node/pod resource stats (RBAC below).
#
# qBittorrent widget is intentionally OMITTED: the qbt WebUI widget needs WebUI
# credentials, but qbittorrent.nix locks the WebUI to OIDC at the gateway and a
# 127.0.0.1-only AuthSubnetWhitelist — homepage cannot authenticate to it. Torrent
# status is surfaced indirectly via the *arr download-client views.
#
# == K8s discovery RBAC ==
# kubernetes.yaml mode=cluster needs the pod's ServiceAccount to list/watch
# cluster objects. We create an explicit ServiceAccount "dash" (raw resource, so
# the name is deterministic for the binding subject), point the controller at it
# (controllers.main.serviceAccount.name = "dash"), and grant a ClusterRole (get/
# list/watch on namespaces, pods, nodes, services, ingresses, gateway-api
# httproutes, and metrics) via a ClusterRoleBinding. RBAC objects are added as raw
# resources post-merged onto the helper output.
#
# == Networking ==
# Egress (mirrors the pre-declared dashboard ingress edges in network-policy.nix):
#   - DNS + gateway-ingress: helper baseline.
#   - in-namespace API edges to sonarr/radarr/lidarr/whisparr/sabnzbd (extraCnps).
#   - kube-apiserver egress (k8s discovery, cluster mode).
#   - internet egress (80/443): homepage fetches dashboard icons from a CDN.
#
# Version: pinned to the latest stable gethomepage release. Bump at deploy time.
{
  config,
  lib,
  ...
}:
let
  media-app = import ./_media-app.nix { inherit lib; };

  appName = "dash";
  homepagePort = 3000; # gethomepage default HTTP port
  saName = "dash";

  # In-namespace service ports the dashboard surfaces (the dashboard ingress edges
  # pre-declared in network-policy.nix). Single source of truth for the egress
  # policy below.
  apiTargets = {
    sonarr = 8989;
    radarr = 7878;
    lidarr = 8686;
    whisparr = 6969;
    sabnzbd = 8080;
  };

  podSelector.matchLabels."app.kubernetes.io/name" = appName;

  apiEgress = svc: port: {
    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = svc; } ];
    toPorts = [
      {
        ports = [
          {
            port = toString port;
            protocol = "TCP";
          }
        ];
      }
    ];
  };

  # API-key env: HOMEPAGE_VAR_<APP>_KEY <- media-arr-api-keys.<app>. Referenced in
  # services.yaml as {{HOMEPAGE_VAR_<APP>_KEY}}. qbittorrent omitted (see header).
  apiKeyApps = [
    "sonarr"
    "radarr"
    "lidarr"
    "sabnzbd"
  ];
  apiKeyEnv = lib.listToAttrs (
    map (
      app:
      lib.nameValuePair "HOMEPAGE_VAR_${lib.toUpper app}_KEY" {
        valueFrom.secretKeyRef = {
          name = "media-arr-api-keys";
          key = app;
        };
      }
    ) apiKeyApps
  );

  # ---- config files ------------------------------------------------------
  settingsYaml = ''
    title: Media Dashboard
    theme: dark
    color: slate
    headerStyle: clean
    layout:
      Media:
        style: row
        columns: 4
      Downloaders:
        style: row
        columns: 2
  '';

  # Static service list with widgets keyed by {{HOMEPAGE_VAR_*_KEY}} env.
  servicesYaml = ''
    - Media:
        - Sonarr:
            href: https://sonarr.json64.dev/
            icon: sonarr.png
            widget:
              type: sonarr
              url: http://sonarr:8989
              key: "{{HOMEPAGE_VAR_SONARR_KEY}}"
        - Radarr:
            href: https://radarr.json64.dev/
            icon: radarr.png
            widget:
              type: radarr
              url: http://radarr:7878
              key: "{{HOMEPAGE_VAR_RADARR_KEY}}"
        - Lidarr:
            href: https://lidarr.json64.dev/
            icon: lidarr.png
            widget:
              type: lidarr
              url: http://lidarr:8686
              key: "{{HOMEPAGE_VAR_LIDARR_KEY}}"
        - Prowlarr:
            href: https://prowlarr.json64.dev/
            icon: prowlarr.png
            # No widget: prowlarr API is admin-gated; surfaced as bookmark only.
    - Downloaders:
        - SABnzbd:
            href: https://nzb.json64.dev/
            icon: sabnzbd.png
            widget:
              type: sabnzbd
              url: http://sabnzbd:8080
              key: "{{HOMEPAGE_VAR_SABNZBD_KEY}}"
        - qBittorrent:
            href: https://torrent.json64.dev/
            icon: qbittorrent.png
            # No widget: the qbt WebUI is OIDC/loopback-locked; homepage cannot
            # authenticate to it. Torrent status is visible via the *arrs.
    - Watch:
        - Jellyfin:
            href: https://jellyfin.json64.dev/
            icon: jellyfin.png
  '';

  widgetsYaml = ''
    - resources:
        backend: kubernetes
        expanded: true
        cpu: true
        memory: true
    - kubernetes:
        cluster:
          show: true
          cpu: true
          memory: true
          showLabel: true
        nodes:
          show: true
          cpu: true
          memory: true
    - search:
        provider: duckduckgo
        target: _blank
  '';

  bookmarksYaml = ''
    - Media:
        - Jellyfin:
            - abbr: JF
              href: https://jellyfin.json64.dev/
        - Bazarr:
            - abbr: BZ
              href: https://bazarr.json64.dev/
        - Whisparr:
            - abbr: WH
              href: https://whisparr.json64.dev/
  '';

  kubernetesYaml = ''
    mode: cluster
  '';

  # The external ConfigMap holding the config files. Delivered as a RAW resource
  # (not via the chart's `configMaps` values) so its data bypasses app-template's
  # Helm `tpl` pass — that pass would try to evaluate homepage's
  # `{{HOMEPAGE_VAR_*}}` substitution tokens as Helm template calls and fail (the
  # same `tpl` foot-gun qbittorrent.nix documents). Mounted by `name` below.
  configMapName = "dash-config";

  # Mount each config file individually via subPath into /app/config.
  configFiles = {
    "settings.yaml" = settingsYaml;
    "services.yaml" = servicesYaml;
    "widgets.yaml" = widgetsYaml;
    "bookmarks.yaml" = bookmarksYaml;
    "kubernetes.yaml" = kubernetesYaml;
  };

  app = media-app.mkMediaApp {
    name = appName;
    port = homepagePort;
    image = {
      repository = "ghcr.io/gethomepage/homepage";
      tag = "v1.13.2";
    };
    inherit (config.den) environments;

    # Stateless: config arrives via ConfigMap (below), no config PVC.
    config-size = null;

    # Homepage fetches dashboard icons from a CDN.
    internetEgress = true;

    # HOMEPAGE_ALLOWED_HOSTS guards against host-header attacks; must match the
    # public hostname the gateway forwards. Plus the *arr/sabnzbd API key env.
    env = {
      HOMEPAGE_ALLOWED_HOSTS = "dash.json64.dev";
    }
    // apiKeyEnv;

    extraCnps = {
      # Egress mirror of the pre-declared dashboard ingress edges.
      "allow-api-egress-${appName}".spec = {
        description = "Allow ${appName} to reach the in-namespace media APIs it surfaces.";
        endpointSelector = podSelector;
        egress = lib.mapAttrsToList apiEgress apiTargets;
      };

      # k8s discovery (kubernetes.yaml mode=cluster) talks to the kube-apiserver.
      "allow-apiserver-egress-${appName}".spec = {
        description = "Allow ${appName} to reach the kube-apiserver for cluster resource discovery.";
        endpointSelector = podSelector;
        egress = [
          {
            toEntities = [ "kube-apiserver" ];
            toPorts = [
              {
                ports = [
                  {
                    port = "6443";
                    protocol = "TCP";
                  }
                ];
              }
            ];
          }
        ];
      };
    };

    extraValues = {
      # Bind the pod to our explicit ServiceAccount (created as a raw resource so
      # its name is deterministic for the ClusterRoleBinding subject below) and
      # mount its token — homepage's cluster-mode discovery authenticates to the
      # kube-apiserver with it (the chart defaults automount to false).
      controllers.main = {
        serviceAccount.name = saName;
        pod.automountServiceAccountToken = true;
      };

      # Mount the external (raw) ConfigMap by name, one file per subPath.
      persistence.config = {
        type = "configMap";
        name = configMapName;
        globalMounts = map (f: {
          path = "/app/config/${f}";
          subPath = f;
          readOnly = true;
        }) (lib.attrNames configFiles);
      };
    };
  };
in
{
  den.aspects.kubernetes.services.media.${appName} = app // {
    # Post-merge the k8s-discovery RBAC (ServiceAccount + ClusterRole +
    # ClusterRoleBinding) onto the helper's application manifests. Forward the
    # helper's formals verbatim (the module system only passes declared args).
    k8s-manifests =
      args@{
        config,
        cluster,
        charts,
        ...
      }:
      lib.recursiveUpdate (app.k8s-manifests args) {
        applications.${appName}.resources = {
          # Config delivered as a raw ConfigMap (bypasses the chart's `tpl` pass —
          # see configMapName note above). Mounted by name via persistence.config.
          configMaps.${configMapName} = {
            metadata.namespace = "media";
            data = configFiles;
          };

          serviceAccounts.${saName} = {
            metadata.namespace = "media";
          };

          clusterRoles."media-${appName}-discovery" = {
            rules = [
              {
                apiGroups = [ "" ];
                resources = [
                  "namespaces"
                  "pods"
                  "nodes"
                  "services"
                ];
                verbs = [
                  "get"
                  "list"
                  "watch"
                ];
              }
              {
                apiGroups = [ "metrics.k8s.io" ];
                resources = [
                  "nodes"
                  "pods"
                ];
                verbs = [
                  "get"
                  "list"
                ];
              }
              {
                apiGroups = [ "networking.k8s.io" ];
                resources = [ "ingresses" ];
                verbs = [
                  "get"
                  "list"
                  "watch"
                ];
              }
              {
                apiGroups = [ "gateway.networking.k8s.io" ];
                resources = [ "httproutes" ];
                verbs = [
                  "get"
                  "list"
                  "watch"
                ];
              }
            ];
          };

          clusterRoleBindings."media-${appName}-discovery" = {
            roleRef = {
              apiGroup = "rbac.authorization.k8s.io";
              kind = "ClusterRole";
              name = "media-${appName}-discovery";
            };
            subjects = [
              {
                kind = "ServiceAccount";
                name = saName;
                namespace = "media";
              }
            ];
          };
        };
      };
  };
}
