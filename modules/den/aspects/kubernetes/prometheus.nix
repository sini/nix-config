# kube-prometheus-stack — Helm chart for in-cluster Prometheus monitoring.
{
  den,
  lib,
  config,
  ...
}:
{
  den.aspects.kubernetes.prometheus = {
    k8s-manifests =
      { cluster, ... }:
      let
        environment = config.den.environments.${cluster.environment};
      in
      {
        applications.kube-prometheus-stack = {
          namespace = "monitoring";

          helm.releases.kube-prometheus-stack = {
            chart = "prometheus-community/kube-prometheus-stack";

            values = {
              prometheus = {
                prometheusSpec = {
                  retention = "30d";
                  retentionSize = "10GB";
                  enableRemoteWriteReceiver = true;

                  storageSpec.volumeClaimTemplate.spec = {
                    storageClassName = "longhorn";
                    accessModes = [ "ReadWriteOnce" ];
                    resources.requests.storage = "50Gi";
                  };
                };
              };

              grafana.enabled = false;
              alertmanager.enabled = true;

              # Use existing node-exporter and kube-state-metrics
              nodeExporter.enabled = true;
              kubeStateMetrics.enabled = true;
            };
          };
        };
      };
  };
}
