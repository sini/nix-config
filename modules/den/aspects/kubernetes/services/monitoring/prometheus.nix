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

                  storageSpec.volumeClaimTemplate.spec = {
                    storageClassName = "longhorn";
                    accessModes = [ "ReadWriteOnce" ];
                    resources.requests.storage = "50Gi";
                  };
                };
              };

              grafana.enabled = false;
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
            };
          };

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
                  # kubelet + cadvisor metrics on every node
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
