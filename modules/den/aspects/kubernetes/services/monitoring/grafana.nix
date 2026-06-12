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
        ...
      }:
      let
        environment = environments.${cluster.environment};
        domain = environment.getDomainFor "grafana-k8s";
        kanidmDomain = environment.getDomainFor "kanidm";
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
          };

          helm.releases.grafana = {
            chart = charts.grafana.grafana;

            values = {
              # State lives in monitoring-pg (see monitoring-pg.nix);
              # dashboards/datasources are fully provisioned, so the pod is
              # stateless: no PVC, rolling updates are safe.
              persistence.enabled = false;

              serviceMonitor.enabled = true;

              # Provision dashboards from labeled ConfigMaps (the
              # kube-prometheus-stack set plus anything we add later).
              sidecar.dashboards = {
                enabled = true;
                searchNamespace = "monitoring";
              };

              # Canonical upstream dashboards that no deployed chart bundles:
              # downloaded by the init container at startup (world:443 egress
              # below covers grafana.com / raw.githubusercontent.com).
              dashboardProviders."dashboardproviders.yaml" = {
                apiVersion = 1;
                providers = [
                  {
                    name = "imported";
                    orgId = 1;
                    folder = "Imported";
                    type = "file";
                    disableDeletion = false;
                    editable = true;
                    options.path = "/var/lib/grafana/dashboards/imported";
                  }
                ];
              };

              dashboards.imported =
                let
                  envoyDashboard =
                    name:
                    "https://raw.githubusercontent.com/envoyproxy/gateway/v1.8.1/charts/gateway-addons-helm/dashboards/${name}.json";
                in
                {
                  # Official Longhorn dashboard (referenced by longhorn docs)
                  longhorn = {
                    gnetId = 13032;
                    revision = 6;
                    datasource = "Prometheus";
                  };
                  # ArgoCD community-canonical dashboard
                  argo-cd = {
                    gnetId = 14584;
                    datasource = "Prometheus";
                  };
                  cert-manager = {
                    gnetId = 11001;
                    datasource = "Prometheus";
                  };
                  # Envoy Gateway's own dashboards (the gateway-addons chart
                  # set, pinned to the deployed EG release line)
                  envoy-gateway-global.url = envoyDashboard "envoy-gateway-global";
                  envoy-proxy-global.url = envoyDashboard "envoy-proxy-global";
                  envoy-clusters.url = envoyDashboard "envoy-clusters";
                  envoy-resources-monitor.url = envoyDashboard "resources-monitor.gen";
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
                datasources = [
                  {
                    name = "Prometheus";
                    type = "prometheus";
                    access = "proxy";
                    url = "http://kube-prometheus-stack-prometheus.monitoring:9090";
                    isDefault = true;
                  }
                  {
                    name = "Loki";
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
