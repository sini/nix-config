# Grafana — Helm chart for in-cluster dashboards.
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
  den.aspects.kubernetes.grafana = {
    k8s-manifests =
      { cluster, ... }:
      let
        environment = environments.${cluster.environment};
        domain = environment.getDomainFor "grafana-k8s";
      in
      {
        applications.grafana = {
          namespace = "monitoring";

          helm.releases.grafana = {
            chart = "grafana/grafana";

            values = {
              persistence = {
                enabled = true;
                storageClassName = "longhorn";
                size = "10Gi";
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

                analytics = {
                  reporting_enabled = false;
                  check_for_updates = false;
                };

                users = {
                  allow_sign_up = false;
                  auto_assign_org_role = "Viewer";
                };
              };
            };
          };
        };
      };
  };
}
