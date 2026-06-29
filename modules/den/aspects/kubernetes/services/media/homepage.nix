# Homepage (gethomepage) — the utility dashboard for the media stack.
#
# == Naming: "dash", not "homepage" ==
# The uplink host already runs a NixOS homepage-dashboard on homepage.json64.dev
# (modules/den/aspects/services/web/homepage.nix, behind oauth2-proxy) and owns
# service-domains "homepage". To avoid a hard domain collision this k8s dashboard
# is named "dash" -> dash.json64.dev (prod.nix services.dash.domain). The Kanidm
# OAuth2 client is "dash" too (kanidm.nix mediaClientDefs.dash), so clientID =
# "dash" and the domain + OIDC contract line up.
#
# == Chart vs raw ==
# nixhelm carries no gethomepage chart, so this is the bjw-s app-template on the
# upstream image (ghcr.io/gethomepage/homepage) with config + RBAC layered in.
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
# httproutes, and metrics) via a ClusterRoleBinding.
#
# == Config delivery (raw ConfigMap) ==
# The config files are delivered as a RAW ConfigMap "dash-config" (not via the
# chart's `configMaps` values) so their data bypasses app-template's Helm `tpl`
# pass — that pass would try to evaluate homepage's `{{HOMEPAGE_VAR_*}}`
# substitution tokens as Helm template calls and fail (the same `tpl` foot-gun
# qbittorrent.nix documents). The ConfigMap is mounted by name, one file per
# subPath, via persistence.config.
#
# == Networking ==
# Egress (mirrors the pre-declared dashboard ingress edges in network-policy.nix):
#   - DNS + gateway-ingress baseline.
#   - in-namespace API edges to sonarr/radarr/lidarr/whisparr/sabnzbd.
#   - kube-apiserver egress (k8s discovery, cluster mode).
#   - internet egress (80/443): homepage fetches dashboard icons from a CDN.
#
# Version: pinned to the latest stable gethomepage release. Bump at deploy time.
{
  den.aspects.kubernetes.services.media.dash = {
    service-domains = [ "dash" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.dash-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/dash-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "dash";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        ...
      }:
      {
        applications.dash = {
          namespace = "media";

          helm.releases.dash = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "ghcr.io/gethomepage/homepage";
                    tag = "v1.13.2";
                  };
                  # baseEnv + HOMEPAGE_ALLOWED_HOSTS (host-header guard; must match
                  # the public hostname the gateway forwards) + the *arr/sabnzbd
                  # API key env (HOMEPAGE_VAR_<APP>_KEY <- media-arr-api-keys.<app>,
                  # referenced in services.yaml as {{HOMEPAGE_VAR_<APP>_KEY}};
                  # qbittorrent omitted, see header).
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    HOMEPAGE_ALLOWED_HOSTS = "dash.json64.dev";
                    HOMEPAGE_VAR_LIDARR_KEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "lidarr";
                    };
                    HOMEPAGE_VAR_RADARR_KEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "radarr";
                    };
                    HOMEPAGE_VAR_SABNZBD_KEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "sabnzbd";
                    };
                    HOMEPAGE_VAR_SONARR_KEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "sonarr";
                    };
                  };
                  envFrom = [ ];
                };

                # Bind the pod to our explicit ServiceAccount (created as a raw
                # resource so its name is deterministic for the ClusterRoleBinding
                # subject below) and mount its token — homepage's cluster-mode
                # discovery authenticates to the kube-apiserver with it (the chart
                # defaults automount to false).
                serviceAccount.name = "dash";
                pod.automountServiceAccountToken = true;
              };

              service.main = {
                controller = "main";
                ports.http.port = 3000; # gethomepage default HTTP port
              };

              # Mount the external (raw) ConfigMap by name, one file per subPath
              # into /app/config. Stateless: config arrives via this ConfigMap, no
              # config PVC.
              persistence.config = {
                type = "configMap";
                name = "dash-config";
                # One mount per config file, in attr-name-sorted order
                # (lib.attrNames over the config-file set: bookmarks, kubernetes,
                # services, settings, widgets).
                globalMounts = [
                  {
                    path = "/app/config/bookmarks.yaml";
                    subPath = "bookmarks.yaml";
                    readOnly = true;
                  }
                  {
                    path = "/app/config/kubernetes.yaml";
                    subPath = "kubernetes.yaml";
                    readOnly = true;
                  }
                  {
                    path = "/app/config/services.yaml";
                    subPath = "services.yaml";
                    readOnly = true;
                  }
                  {
                    path = "/app/config/settings.yaml";
                    subPath = "settings.yaml";
                    readOnly = true;
                  }
                  {
                    path = "/app/config/widgets.yaml";
                    subPath = "widgets.yaml";
                    readOnly = true;
                  }
                ];
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-dash.spec = {
                description = "Allow Envoy Gateway proxies to reach dash.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "dash";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "3000";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-dash.spec = {
                description = "Allow dash to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "dash";
                egress = [
                  {
                    toEndpoints = [
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "kube-system";
                          "k8s-app" = "kube-dns";
                        };
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                          {
                            port = "53";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-internet-egress-dash.spec = {
                description = "Allow dash to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "dash";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "80";
                            protocol = "TCP";
                          }
                          {
                            port = "443";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Egress mirror of the pre-declared dashboard ingress edges (the
              # in-namespace media APIs the dashboard surfaces). Endpoints in
              # attr-name-sorted order: lidarr, radarr, sabnzbd, sonarr, whisparr.
              allow-api-egress-dash.spec = {
                description = "Allow dash to reach the in-namespace media APIs it surfaces.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "dash";
                egress = [
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "lidarr"; } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8686";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "radarr"; } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "7878";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "sabnzbd"; } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8080";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "sonarr"; } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8989";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "whisparr"; } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6969";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # k8s discovery (kubernetes.yaml mode=cluster) talks to the
              # kube-apiserver.
              allow-apiserver-egress-dash.spec = {
                description = "Allow dash to reach the kube-apiserver for cluster resource discovery.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "dash";
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

            httpRoutes.dash.spec = {
              hostnames = [ (cluster.domainFor "dash") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "dash"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "dash";
                      port = 3000;
                    }
                  ];
                }
              ];
            };

            securityPolicies."dash-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "dash";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "dash";
                clientID = "dash";
                clientSecret.name = "dash-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                  "offline_access"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.dash-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.dash-oidc-client-secret.sopsRef;
            };

            # Config delivered as a raw ConfigMap (bypasses the chart's `tpl` pass
            # — see header note). Mounted by name via persistence.config above.
            configMaps.dash-config = {
              metadata.namespace = "media";
              data = {
                "settings.yaml" = ''
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
                "services.yaml" = ''
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

                "widgets.yaml" = ''
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

                "bookmarks.yaml" = ''
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

                "kubernetes.yaml" = ''
                  mode: cluster
                '';
              };
            };

            serviceAccounts.dash = {
              metadata.namespace = "media";
            };

            clusterRoles."media-dash-discovery" = {
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

            clusterRoleBindings."media-dash-discovery" = {
              roleRef = {
                apiGroup = "rbac.authorization.k8s.io";
                kind = "ClusterRole";
                name = "media-dash-discovery";
              };
              subjects = [
                {
                  kind = "ServiceAccount";
                  name = "dash";
                  namespace = "media";
                }
              ];
            };
          };
        };
      };
  };
}
