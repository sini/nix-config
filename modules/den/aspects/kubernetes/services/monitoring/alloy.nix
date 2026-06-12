# Alloy — Grafana Alloy DaemonSet shipping pod logs to loki.
#
# Tails CRI logs from /var/log/pods on every node (filtered to the local
# node via the kubernetes API) and pushes to the loki service. Positions
# live on a hostPath so a pod restart doesn't re-ingest every log file.
{
  den.aspects.kubernetes.services.monitoring.alloy = {
    k8s-manifests =
      { charts, ... }:
      {
        applications.alloy = {
          namespace = "monitoring";

          helm.releases.alloy = {
            chart = charts.grafana.alloy;

            values = {
              serviceMonitor.enabled = true;

              controller = {
                type = "daemonset";
                volumes.extra = [
                  {
                    name = "alloy-data";
                    hostPath = {
                      path = "/var/lib/alloy";
                      type = "DirectoryOrCreate";
                    };
                  }
                ];
              };

              alloy = {
                # /var/log/pods files are root-owned
                securityContext = {
                  runAsUser = 0;
                  runAsGroup = 0;
                };

                mounts = {
                  varlog = true;
                  extra = [
                    {
                      name = "alloy-data";
                      mountPath = "/tmp/alloy";
                    }
                  ];
                };

                extraEnv = [
                  {
                    name = "NODE_NAME";
                    valueFrom.fieldRef.fieldPath = "spec.nodeName";
                  }
                ];

                configMap.content = ''
                  discovery.kubernetes "pods" {
                    role = "pod"

                    selectors {
                      role  = "pod"
                      field = "spec.nodeName=" + sys.env("NODE_NAME")
                    }
                  }

                  discovery.relabel "pod_logs" {
                    targets = discovery.kubernetes.pods.targets

                    rule {
                      source_labels = ["__meta_kubernetes_namespace"]
                      target_label  = "namespace"
                    }

                    rule {
                      source_labels = ["__meta_kubernetes_pod_name"]
                      target_label  = "pod"
                    }

                    rule {
                      source_labels = ["__meta_kubernetes_pod_container_name"]
                      target_label  = "container"
                    }

                    rule {
                      source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
                      target_label  = "app"
                    }

                    rule {
                      source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
                      separator     = "/"
                      action        = "replace"
                      replacement   = "/var/log/pods/*$1/*.log"
                      target_label  = "__path__"
                    }
                  }

                  local.file_match "pod_logs" {
                    path_targets = discovery.relabel.pod_logs.output
                  }

                  loki.source.file "pod_logs" {
                    targets    = local.file_match.pod_logs.targets
                    forward_to = [loki.process.pod_logs.receiver]
                  }

                  loki.process "pod_logs" {
                    stage.cri { }

                    forward_to = [loki.write.loki.receiver]
                  }

                  loki.write "loki" {
                    endpoint {
                      url = "http://loki.monitoring.svc:3100/loki/api/v1/push"
                    }
                  }
                '';
              };
            };
          };

          # Pod discovery (node-local filter) talks to the kube-apiserver;
          # the loki push stays inside the cluster (allow-internal-egress).
          resources.ciliumNetworkPolicies = {
            allow-alloy-kube-apiserver-egress = {
              spec = {
                endpointSelector.matchLabels."app.kubernetes.io/instance" = "alloy";
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
