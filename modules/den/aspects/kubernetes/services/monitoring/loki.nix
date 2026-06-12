# Loki — Helm chart for in-cluster log aggregation.
#
# Single-binary deployment on longhorn storage; alloy (see alloy.nix) ships
# pod logs here. The chart's nginx gateway is disabled — consumers hit the
# loki service directly, and the gateway's resolver default (kube-dns)
# doesn't exist on k3s (the service is named coredns).
{
  den.aspects.kubernetes.services.monitoring.loki = {
    k8s-manifests =
      { charts, ... }:
      {
        applications.loki = {
          namespace = "monitoring";

          helm.releases.loki = {
            chart = charts.grafana.loki;

            # The chart gates its ServiceMonitor/PrometheusRule on cluster
            # capabilities, which offline helm template never satisfies —
            # declare the live CRDs explicitly so monitoring.* renders.
            extraOpts = [
              "--api-versions"
              "monitoring.coreos.com/v1/ServiceMonitor"
              "--api-versions"
              "monitoring.coreos.com/v1/PrometheusRule"
            ];

            values = {
              # Without this the chart renders SimpleScalable and, with
              # read/write/backend at 0, no loki pods at all.
              deploymentMode = "SingleBinary";

              loki = {
                auth_enabled = false;

                commonConfig.replication_factor = 1;

                storage = {
                  type = "filesystem";
                };

                schemaConfig.configs = [
                  {
                    from = "2026-06-01";
                    store = "tsdb";
                    object_store = "filesystem";
                    schema = "v13";
                    index = {
                      prefix = "index_";
                      period = "24h";
                    };
                  }
                ];

                limits_config = {
                  retention_period = "30d";
                };

                compactor = {
                  retention_enabled = true;
                  retention_delete_delay = "2h";
                  delete_request_store = "filesystem";
                };
              };

              singleBinary = {
                replicas = 1;
                persistence = {
                  enabled = true;
                  storageClass = "longhorn";
                  size = "50Gi";
                };
              };

              # Disable distributed components
              read.replicas = 0;
              write.replicas = 0;
              backend.replicas = 0;

              gateway.enabled = false;

              # Self-monitoring: ServiceMonitor for loki's own metrics,
              # upstream loki dashboards for the grafana sidecar, and the
              # chart's PrometheusRule alert/record set.
              monitoring = {
                serviceMonitor.enabled = true;
                dashboards = {
                  enabled = true;
                  namespace = "monitoring";
                };
                rules.enabled = true;
              };
            };
          };

          # The rules sidecar (loki-sc-rules) watches the apiserver for
          # rule ConfigMaps/Secrets; the cluster default-denies egress to
          # non-endpoint entities.
          resources.ciliumNetworkPolicies = {
            allow-loki-kube-apiserver-egress = {
              spec = {
                endpointSelector.matchLabels."app.kubernetes.io/name" = "loki";
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
          };
        };
      };
  };
}
