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
            };
          };
        };
      };
  };
}
