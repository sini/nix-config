# Loki — Helm chart for in-cluster log aggregation.
{
  den,
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.kubernetes.loki = {
    k8s-manifests =
      { cluster, ... }:
      let
        environment = environments.${cluster.environment};
      in
      {
        applications.loki = {
          namespace = "monitoring";

          helm.releases.loki = {
            chart = "grafana/loki";

            values = {
              loki = {
                auth_enabled = false;

                storage = {
                  type = "filesystem";
                };

                schemaConfig.configs = [
                  {
                    from = "2020-10-24";
                    store = "boltdb-shipper";
                    object_store = "filesystem";
                    schema = "v11";
                    index = {
                      prefix = "index_";
                      period = "24h";
                    };
                  }
                ];

                limits_config = {
                  retention_period = "30d";
                  allow_structured_metadata = false;
                };

                compactor = {
                  retention_enabled = true;
                  retention_delete_delay = "2h";
                };
              };

              # Single-binary mode for simplicity
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

              # Deploy promtail for log collection
              promtail.enabled = true;
            };
          };
        };
      };
  };
}
