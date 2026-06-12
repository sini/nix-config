# Grafana — Helm chart for in-cluster dashboards.
#
# Routed through the default gateway; auth is grafana-native OIDC against
# kanidm (clientID grafana-k8s — the host-level grafana on the
# metrics-ingester owns the plain "grafana" client) with the same
# group-to-role ACL mapping as the host instance. Dashboards are
# provisioned by the sidecar from ConfigMaps labeled grafana_dashboard;
# kube-prometheus-stack force-deploys its standard dashboard set even
# with its bundled grafana disabled (see prometheus.nix).
{
  config,
  lib,
  ...
}:
let
  inherit (lib) concatStringsSep splitString take;
  environments = config.den.environments;
  domainToResourceName =
    domain:
    let
      parts = splitString "." domain;
      topDomain = lib.reverseList (take 2 (lib.reverseList parts));
    in
    concatStringsSep "-" topDomain;
in
{
  den.aspects.kubernetes.services.monitoring.grafana = {
    k8s-manifests =
      {
        config,
        cluster,
        charts,
        pkgs,
        ...
      }:
      let
        environment = environments.${cluster.environment};
        domain = environment.getDomainFor "grafana-k8s";
        kanidmDomain = environment.getDomainFor "kanidm";

        # Canonical upstream dashboards that no deployed chart bundles,
        # pinned and transformed at BUILD time (no runtime downloads): title
        # normalized, grafana.com `__inputs` datasource placeholders bound to
        # the Prometheus datasource. Rendered below as sidecar ConfigMaps
        # with a grafana_folder annotation.
        mkDashboardJson =
          {
            name,
            title,
            url,
            sha256,
            fixDatasource ? false,
          }:
          builtins.readFile (
            pkgs.runCommand "grafana-dashboard-${name}"
              {
                src = pkgs.fetchurl { inherit url sha256; };
                nativeBuildInputs = [
                  pkgs.jq
                  pkgs.gnused
                ];
              }
              ''
                ${
                  if fixDatasource then
                    ''sed '/-- .* --/! s/"datasource":.*,/"datasource": "Prometheus",/g' "$src"''
                  else
                    ''cat "$src"''
                } | jq '.title = "${title}"' > "$out"
              ''
          );

        envoyDashboardUrl =
          name:
          "https://raw.githubusercontent.com/envoyproxy/gateway/v1.8.1/charts/gateway-addons-helm/dashboards/${name}.json";

        # Log-browsing dashboards authored here (community ones key off a
        # job-based label schema; ours is namespace/pod/container). Stable
        # uids give stable URLs; the loki datasource uid is pinned above.
        lokiDs = {
          type = "loki";
          uid = "loki";
        };

        mkLabelVar = name: query: {
          inherit name;
          type = "query";
          datasource = lokiDs;
          inherit query;
          refresh = 2;
          includeAll = true;
          multi = true;
          allValue = ".+";
          current = {
            selected = true;
            text = [ "All" ];
            value = [ "$__all" ];
          };
        };

        searchVar = {
          name = "search";
          type = "textbox";
          label = "search";
          current = {
            text = "";
            value = "";
          };
        };

        mkLogsDashboard =
          {
            uid,
            title,
            variables,
            selector,
            volumeBy,
          }:
          {
            inherit uid title;
            schemaVersion = 39;
            version = 1;
            editable = true;
            time = {
              from = "now-1h";
              to = "now";
            };
            templating.list = variables ++ [ searchVar ];
            panels = [
              {
                title = "Log volume";
                type = "timeseries";
                datasource = lokiDs;
                gridPos = {
                  h = 6;
                  w = 24;
                  x = 0;
                  y = 0;
                };
                options.legend.displayMode = "list";
                fieldConfig.defaults.custom = {
                  drawStyle = "bars";
                  fillOpacity = 50;
                };
                targets = [
                  {
                    refId = "A";
                    datasource = lokiDs;
                    expr = "sum by (${volumeBy}) (count_over_time(${selector} |= `$search` [$__auto]))";
                    legendFormat = "{{${volumeBy}}}";
                  }
                ];
              }
              {
                title = "Logs";
                type = "logs";
                datasource = lokiDs;
                gridPos = {
                  h = 20;
                  w = 24;
                  x = 0;
                  y = 6;
                };
                options = {
                  showTime = true;
                  wrapLogMessage = true;
                  enableLogDetails = true;
                  sortOrder = "Descending";
                  dedupStrategy = "none";
                };
                targets = [
                  {
                    refId = "A";
                    datasource = lokiDs;
                    expr = "${selector} |= `$search`";
                  }
                ];
              }
            ];
          };

        localDashboards = {
          pod-logs = {
            folder = "Logs";
            dashboard = mkLogsDashboard {
              uid = "pod-logs";
              title = "Pod Logs";
              variables = [
                (mkLabelVar "namespace" "label_values(namespace)")
                (mkLabelVar "pod" "label_values({namespace=~\"$namespace\"}, pod)")
                (mkLabelVar "container" "label_values({namespace=~\"$namespace\", pod=~\"$pod\"}, container)")
              ];
              selector = "{namespace=~\"$namespace\", pod=~\"$pod\", container=~\"$container\"}";
              volumeBy = "pod";
            };
          };
          kubernetes-events = {
            folder = "Logs";
            dashboard = mkLogsDashboard {
              uid = "k8s-events";
              title = "Kubernetes Events";
              variables = [
                (mkLabelVar "namespace" "label_values({job=\"loki.source.kubernetes_events\"}, namespace)")
              ];
              selector = "{job=\"loki.source.kubernetes_events\", namespace=~\"$namespace\"}";
              volumeBy = "namespace";
            };
          };
        };

        importedDashboards = {
          argocd = {
            title = "ArgoCD";
            folder = "GitOps";
            url = "https://grafana.com/api/dashboards/14584/revisions/1/download";
            sha256 = "1ab8sdrd8ngaw4p9vzldzln5x1xqbp09wbmy9lkyv0gaxnl7nyqr";
            fixDatasource = true;
          };
          cert-manager = {
            title = "cert-manager";
            folder = "Security";
            url = "https://grafana.com/api/dashboards/11001/revisions/1/download";
            sha256 = "01q5ks0q3sabnw1rmmpz1yl864i47hbfxw0ksk6vpibrwm52p879";
            fixDatasource = true;
          };
          longhorn = {
            title = "Longhorn";
            folder = "Storage";
            url = "https://grafana.com/api/dashboards/13032/revisions/6/download";
            sha256 = "0rfdrixrj53czyxawvqf47z5rcgbiz2fr91ih9a7rj1n9akzhgvw";
            fixDatasource = true;
          };
          envoy-gateway = {
            title = "Envoy Gateway";
            folder = "Networking";
            url = envoyDashboardUrl "envoy-gateway-global";
            sha256 = "0knr3cgqf4cg31hk4ds39mywz1xpxxfirb886y2d42i7bdh2rp1c";
          };
          envoy-proxy = {
            title = "Envoy Proxy";
            folder = "Networking";
            url = envoyDashboardUrl "envoy-proxy-global";
            sha256 = "1dv7rgcmxap5cr7ww9q6icl0kwhjgaygs89acxgaqf7k1kcr40kz";
          };
          envoy-clusters = {
            title = "Envoy Clusters";
            folder = "Networking";
            url = envoyDashboardUrl "envoy-clusters";
            sha256 = "1ghh652xv48l72scyan0d2fjx9ll19kgx9xm3cifhqn5763mjvl9";
          };
          envoy-resources = {
            title = "Envoy Gateway Resources";
            folder = "Networking";
            url = envoyDashboardUrl "resources-monitor.gen";
            sha256 = "0h55cpc8k3294w8pjri6shkqqxscqnr8qs87k1dkhhk79xrmrzhl";
          };
        };
      in
      {
        applications.grafana = {
          namespace = "monitoring";

          # Dashboard ConfigMaps (the CNPG one is ~250KiB) blow past the
          # 256KiB last-applied annotation limit under client-side apply.
          syncPolicy.syncOptions.serverSideApply = true;
          compareOptions.serverSideDiff = true;

          # CNPG cluster dashboard — rendered as a labeled ConfigMap the
          # sidecar picks up. The operator chart's grafanaDashboard.create is
          # a stub (the JSON moved to the dedicated dashboards repo this
          # chart is pinned from).
          helm.releases.cnpg-grafana-cluster = {
            chart = charts.cnpg-grafana-dashboards.cluster;
            values.grafanaDashboard.annotations.grafana_folder = "Databases";
          };

          helm.releases.grafana = {
            chart = charts.grafana.grafana;

            values = {
              # State lives in monitoring-pg (see monitoring-pg.nix);
              # dashboards/datasources are fully provisioned, so the pod is
              # stateless: no PVC, rolling updates are safe.
              persistence.enabled = false;

              serviceMonitor.enabled = true;

              # Provision dashboards from labeled ConfigMaps; the
              # grafana_folder annotation routes each into a real folder.
              sidecar.dashboards = {
                enabled = true;
                searchNamespace = "monitoring";
                folderAnnotation = "grafana_folder";
                provider.foldersFromFilesStructure = true;
              };

              # Secrets land as env vars (GF_ vars override grafana.ini),
              # sourced from SopsSecrets / the CNPG role secret.
              envValueFrom = {
                GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET.secretKeyRef = {
                  name = "grafana-k8s-oidc-client-secret";
                  key = "client-secret";
                };
                GF_DATABASE_PASSWORD.secretKeyRef = {
                  name = "monitoring-pg-grafana-password";
                  key = "password";
                };
              };

              datasources."datasources.yaml" = {
                apiVersion = 1;
                # The original records were created without explicit uids;
                # provisioning matches BY uid once one is specified and
                # hard-fails on the lookup miss. Deleting by name first makes
                # the pinned-uid recreate idempotent (provisioned datasources
                # carry no state worth keeping).
                deleteDatasources = [
                  {
                    name = "Prometheus";
                    orgId = 1;
                  }
                  {
                    name = "Loki";
                    orgId = 1;
                  }
                ];
                datasources = [
                  {
                    name = "Prometheus";
                    uid = "prometheus";
                    type = "prometheus";
                    access = "proxy";
                    url = "http://kube-prometheus-stack-prometheus.monitoring:9090";
                    isDefault = true;
                  }
                  {
                    name = "Loki";
                    uid = "loki";
                    type = "loki";
                    access = "proxy";
                    url = "http://loki.monitoring:3100";
                  }
                ];
              };

              "grafana.ini" = {
                server = {
                  inherit domain;
                  root_url = "https://${domain}";
                };

                # Backing store in monitoring-pg (password via
                # GF_DATABASE_PASSWORD above). ssl_mode require: CNPG serves
                # TLS with a cluster-internal CA.
                database = {
                  type = "postgres";
                  host = "monitoring-pg-rw.monitoring:5432";
                  name = "grafana";
                  user = "grafana";
                  ssl_mode = "require";
                };

                analytics = {
                  reporting_enabled = false;
                  check_for_updates = false;
                };

                users = {
                  allow_sign_up = false;
                  auto_assign_org_role = "Viewer";
                };

                # Mirrors the host-level grafana OIDC config (same kanidm
                # ACL groups: grafana.{editors,admins,server-admins}).
                "auth.generic_oauth" = {
                  enabled = true;
                  name = "KanIDM";
                  icon = "signin";
                  allow_sign_up = true;
                  auto_login = true;
                  client_id = "grafana-k8s";
                  scopes = "openid email profile";
                  login_attribute_path = "preferred_username";
                  auth_url = "https://${kanidmDomain}/ui/oauth2";
                  token_url = "https://${kanidmDomain}/oauth2/token";
                  api_url = "https://${kanidmDomain}/oauth2/openid/grafana-k8s/userinfo";
                  use_pkce = true;
                  use_refresh_token = true;
                  role_attribute_path = "contains(groups[*], 'server_admin') && 'GrafanaAdmin' || contains(groups[*], 'admin') && 'Admin' || contains(groups[*], 'editor') && 'Editor' || 'Viewer'";
                  role_attribute_strict = false;
                  allow_assign_grafana_admin = true;
                  skip_org_role_sync = false;
                };
              };
            };
          };

          resources = {
            configMaps =
              lib.mapAttrs' (
                name: d:
                lib.nameValuePair "dashboard-${name}" {
                  metadata = {
                    labels.grafana_dashboard = "1";
                    annotations.grafana_folder = d.folder;
                  };
                  data."${name}.json" = mkDashboardJson {
                    inherit name;
                    inherit (d) title url sha256;
                    fixDatasource = d.fixDatasource or false;
                  };
                }
              ) importedDashboards
              // lib.mapAttrs' (
                name: d:
                lib.nameValuePair "dashboard-${name}" {
                  metadata = {
                    labels.grafana_dashboard = "1";
                    annotations.grafana_folder = d.folder;
                  };
                  data."${name}.json" = builtins.toJSON d.dashboard;
                }
              ) localDashboards;

            httpRoutes.grafana.spec = {
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${domainToResourceName domain}-https";
                }
              ];
              hostnames = [ domain ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "grafana";
                      port = 80;
                    }
                  ];
                }
              ];
            };

            secrets.grafana-k8s-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.grafana-k8s-oidc-client-secret.sopsRef;
            };

            ciliumNetworkPolicies = {
              # The dashboard sidecar watches ConfigMaps via the apiserver.
              allow-grafana-kube-apiserver-egress.spec = {
                description = "Allow the grafana dashboard sidecar to watch the kube-apiserver.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "grafana";
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

              # OIDC token/userinfo calls go server-side from the grafana pod
              # to kanidm, which lives outside the cluster (world entity).
              allow-grafana-kanidm-egress.spec = {
                description = "Allow grafana to reach kanidm for OIDC token/userinfo calls.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "grafana";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
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
            };
          };
        };
      };

    age-secrets =
      { cluster, ... }:
      let
        env = environments.${cluster.environment};
      in
      {
        age.secrets.grafana-k8s-oidc-client-secret = {
          rekeyFile = env.secretPath + "/oidc/grafana-k8s-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "grafana-k8s";
          };
        };
      };
  };
}
