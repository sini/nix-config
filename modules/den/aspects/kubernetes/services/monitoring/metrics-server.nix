# metrics-server — the Kubernetes Metrics API (metrics.k8s.io).
#
# k3s's bundled copy is disabled (--disable metrics-server, like every other
# bundled component this cluster replaces); nothing reinstated it, so
# `kubectl top`, HPA, and every metrics.k8s.io consumer errored — longhorn's
# node/instance-manager CPU+memory collectors among them ("the server could
# not find the requested resource (get nodes.metrics.k8s.io)").
#
# k3s signs kubelet serving certs with the cluster CA, so no
# --kubelet-insecure-tls is needed. Ingress stays open (the aggregated-API
# calls arrive from the host-network apiserver); egress to the kubelets is
# host-entity traffic and needs the explicit rule below.
{
  den.aspects.kubernetes.services.monitoring.metrics-server = {
    k8s-manifests =
      { charts, ... }:
      {
        applications.metrics-server = {
          namespace = "kube-system";

          helm.releases.metrics-server = {
            chart = charts.kubernetes-sigs.metrics-server;
          };

          resources.ciliumNetworkPolicies.allow-metrics-server-egress = {
            metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
            spec = {
              description = "Allow metrics-server to reach the kube-apiserver and every node's kubelet.";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "metrics-server";
              egress = [
                {
                  toEntities = [ "kube-apiserver" ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "443";
                          protocol = "TCP";
                        }
                        {
                          port = "6443";
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
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
        };
      };
  };
}
