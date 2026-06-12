# kube-prometheus-stack — Helm chart for in-cluster Prometheus monitoring.
#
# Scopes itself to kubernetes-level signals: apiserver, kubelet/cadvisor,
# coredns, kube-state-metrics, and in-cluster ServiceMonitors/PodMonitors.
# Node-level metrics stay with the host stack (every server already runs
# prometheus-exporter on :9100 — an in-cluster node-exporter would clash
# on the hostPort and duplicate the host stack's ownership).
{
  den.aspects.kubernetes.services.monitoring.prometheus = {
    k8s-manifests =
      { charts, ... }:
      {
        applications.kube-prometheus-stack = {
          namespace = "monitoring";

          # The prometheus-operator CRDs blow past the 256KiB annotation
          # limit under client-side apply.
          syncPolicy.syncOptions.serverSideApply = true;

          helm.releases.kube-prometheus-stack = {
            chart = charts.prometheus-community.kube-prometheus-stack;

            values = {
              prometheus = {
                prometheusSpec = {
                  retention = "30d";
                  retentionSize = "10GB";
                  enableRemoteWriteReceiver = true;

                  # Pick up ServiceMonitors/PodMonitors/Probes/Rules from any
                  # namespace regardless of release label — CNPG, exportarr,
                  # and other app-owned monitors don't carry the chart's
                  # release label.
                  serviceMonitorSelectorNilUsesHelmValues = false;
                  podMonitorSelectorNilUsesHelmValues = false;
                  probeSelectorNilUsesHelmValues = false;
                  ruleSelectorNilUsesHelmValues = false;

                  storageSpec.volumeClaimTemplate.spec = {
                    storageClassName = "longhorn";
                    accessModes = [ "ReadWriteOnce" ];
                    resources.requests.storage = "50Gi";
                  };
                };
              };

              # The bundled grafana stays off (grafana.nix owns the instance),
              # but its standard dashboard ConfigMaps still render for the
              # sidecar there to pick up.
              grafana = {
                enabled = false;
                forceDeployDashboards = true;
                sidecar.dashboards.annotations.grafana_folder = "Kubernetes";
              };
              alertmanager.enabled = true;

              # Admission webhook certs via cert-manager instead of the
              # certgen hook jobs: PreSync hooks run before any of the app's
              # resources (including its network policies) are applied, so
              # the job can never reach the apiserver under the cluster's
              # default-deny egress.
              prometheusOperator.admissionWebhooks.certManager.enabled = true;

              # Node metrics are host-stack-owned (see header).
              nodeExporter.enabled = false;
              kubeStateMetrics.enabled = true;

              # k3s embeds the control-plane components in the k3s process;
              # there are no separate endpoints for these to scrape.
              kubeControllerManager.enabled = false;
              kubeScheduler.enabled = false;
              kubeProxy.enabled = false;
              kubeEtcd.enabled = false;

              # The chart's coredns Service selects k8s-app=kube-dns; our
              # coredns chart labels its pods k8s-app=coredns, so the default
              # selector matches nothing and the coredns dashboards read empty.
              coreDns.service.selector."k8s-app" = "coredns";
            };
          };

          # PodMonitors for workloads whose charts ship no monitor of their
          # own (gateway-helm has none). They live here in monitoring and
          # select across namespaces; raw objects because there is no typed
          # accessor without a kube-prometheus-stack crds bridge (planned
          # alongside PrometheusRule authoring for alerting).
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "envoy-gateway";
                namespace = "monitoring";
              };
              spec = {
                namespaceSelector.matchNames = [ "envoy-gateway-system" ];
                selector.matchLabels."control-plane" = "envoy-gateway";
                podMetricsEndpoints = [ { port = "metrics"; } ];
              };
            }
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "envoy-proxies";
                namespace = "monitoring";
              };
              spec = {
                namespaceSelector.matchNames = [ "gateways" ];
                selector.matchLabels."app.kubernetes.io/component" = "proxy";
                # Envoy serves prometheus on the admin-style stats path, not
                # /metrics (the controller does use /metrics).
                podMetricsEndpoints = [
                  {
                    port = "metrics";
                    path = "/stats/prometheus";
                  }
                ];
              };
            }
          ];

          # The cluster default-denies egress to anything that isn't a
          # cilium-managed endpoint; the apiserver and kubelets are
          # host-network and need explicit entity rules.
          resources.ciliumNetworkPolicies = {
            allow-operator-kube-apiserver-egress = {
              spec = {
                endpointSelector.matchLabels.app = "kube-prometheus-stack-operator";
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

            allow-prometheus-scrape-egress = {
              spec = {
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prometheus";
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
                  # Host-network scrape targets on every node: kubelet
                  # (10250), cilium agent (9962), cilium operator (9963),
                  # hubble metrics (9965).
                  {
                    toEntities = [
                      "host"
                      "remote-node"
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "10250";
                            protocol = "TCP";
                          }
                          {
                            port = "9962";
                            protocol = "TCP";
                          }
                          {
                            port = "9963";
                            protocol = "TCP";
                          }
                          {
                            port = "9965";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };

            allow-kube-state-metrics-kube-apiserver-egress = {
              spec = {
                endpointSelector.matchLabels."app.kubernetes.io/name" = "kube-state-metrics";
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
