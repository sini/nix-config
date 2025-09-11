{
  # Monitoring stack application
  applications.monitoring = {
    namespace = "monitoring";
    createNamespace = true;

    resources = {
      # Prometheus operator and stack
      helms.prometheus-stack = {
        chart = {
          name = "kube-prometheus-stack";
          repo = "https://prometheus-community.github.io/helm-charts";
          version = "65.1.1";
        };
        values = {
          prometheusOperator = {
            enabled = true;
          };
          prometheus = {
            prometheusSpec = {
              retention = "30d";
              storageSpec = {
                volumeClaimTemplate = {
                  spec = {
                    storageClassName = "longhorn";
                    accessModes = [ "ReadWriteOnce" ];
                    resources = {
                      requests = {
                        storage = "50Gi";
                      };
                    };
                  };
                };
              };
            };
          };
          grafana = {
            enabled = true;
            persistence = {
              enabled = true;
              storageClassName = "longhorn";
              size = "10Gi";
            };
            adminPassword = "admin"; # TODO: Use proper secret management
          };
          alertmanager = {
            enabled = true;
          };
        };
      };

      # Grafana dashboards
      configMaps.grafana-dashboards = {
        data = {
          "k8s-cluster.json" = builtins.readFile ./dashboards/k8s-cluster.json;
        };
        metadata.labels = {
          "grafana_dashboard" = "1";
        };
      };
    };
  };
}
