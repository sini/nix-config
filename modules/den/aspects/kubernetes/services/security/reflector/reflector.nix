# Emberstack reflector — cross-namespace Secret/ConfigMap replication.
#
# Cross-cutting infra: a consumer's GarageKey-minted S3 credential Secret carries
# reflector annotations that replicate it into the consumer's own namespace
# (declared with the consumer, not the garage module). Deploy ahead of any
# annotated Secret.
{
  den.aspects.kubernetes.services.security.reflector = {
    k8s-manifests =
      { charts, ... }:
      {
        applications.reflector = {
          namespace = "reflector";

          helm.releases.reflector = {
            chart = charts.emberstack.reflector;
          };

          # The clusterwide `allow-internal-egress` policy selects every pod and
          # permits only pod-to-pod egress (no `kube-apiserver` entity, which is
          # off-CIDR/host-network), so any namespace needing the API must allow it
          # explicitly. Reflector watches + writes Secrets/ConfigMaps cluster-wide
          # through the apiserver (and its health check probes `/version`) — without
          # this it crash-loops on connection timeouts. Mirrors the garage
          # namespace's apiserver-egress rule (network-policy.nix). DNS is already
          # covered by the clusterwide rule (CoreDNS pods are endpoints).
          resources.ciliumNetworkPolicies.allow-reflector-apiserver-egress = {
            metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
            spec = {
              description = "Reflector to kube-apiserver (watch/replicate Secrets+ConfigMaps; health check).";
              endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "reflector";
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
        };
      };
  };
}
