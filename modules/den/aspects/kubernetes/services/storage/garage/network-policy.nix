# CiliumNetworkPolicies for the garage namespace. Default-deny once any policy
# selects a pod, so every legitimate flow is enumerated. NO world egress —
# Garage needs none.
{
  den.aspects.kubernetes.services.storage.garage.network-policy = {
    k8s-manifests =
      { ... }:
      {
        applications.garage.resources.ciliumNetworkPolicies = {
          # RPC mesh: Garage pods talk to each other on 3901 (ingress + egress).
          allow-garage-rpc-mesh.spec = {
            description = "Garage inter-node RPC mesh (3901) within the garage namespace.";
            endpointSelector.matchLabels."app.kubernetes.io/name" = "garage";
            ingress = [
              {
                fromEndpoints = [ { matchLabels."app.kubernetes.io/name" = "garage"; } ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "3901";
                        protocol = "TCP";
                      }
                    ];
                  }
                ];
              }
            ];
            egress = [
              {
                toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "garage"; } ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "3901";
                        protocol = "TCP";
                      }
                    ];
                  }
                ];
              }
            ];
          };

          # S3 ingress on 3900 from the gateways namespace (public route backend)
          # and in-cluster consumer namespaces (burrito).
          allow-garage-s3-ingress.spec = {
            description = "S3 API (3900) ingress from gateways + consumer namespaces.";
            endpointSelector.matchLabels."app.kubernetes.io/name" = "garage";
            ingress = [
              {
                fromEndpoints = [
                  { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                  { matchLabels."k8s:io.kubernetes.pod.namespace" = "burrito"; }
                ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "3900";
                        protocol = "TCP";
                      }
                    ];
                  }
                ];
              }
            ];
          };

          # Admin API (3903) ingress from within the garage namespace: the
          # operator polls each node's admin API (GetClusterStatus) to discover
          # node IDs, connect peers and drive layout — without this it times out
          # and the cluster never forms ("Layout not ready"). garage-ui also uses
          # it. The admin API is admin-token-gated, so namespace-scoping is safe.
          allow-garage-admin-ingress.spec = {
            description = "Admin API (3903) ingress from the garage namespace (operator + UI).";
            endpointSelector.matchLabels."app.kubernetes.io/name" = "garage";
            ingress = [
              {
                fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "garage"; } ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "3903";
                        protocol = "TCP";
                      }
                    ];
                  }
                ];
              }
            ];
          };

          # kube-apiserver egress: Garage k8s peer discovery + operator CR
          # reconciliation (toEntities, NOT world — the coder-pg precedent).
          allow-garage-apiserver-egress = {
            metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
            spec = {
              description = "garage-ns pods (Garage + operator) to kube-apiserver.";
              endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "garage";
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
              ];
            };
          };

          # DNS egress for service-name resolution.
          allow-garage-dns-egress.spec = {
            description = "garage-ns pods resolve via kube-dns.";
            endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "garage";
            egress = [
              {
                toEndpoints = [
                  {
                    matchLabels = {
                      "k8s:io.kubernetes.pod.namespace" = "kube-system";
                      "k8s-app" = "kube-dns";
                    };
                  }
                ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "53";
                        protocol = "UDP";
                      }
                      {
                        port = "53";
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
}
