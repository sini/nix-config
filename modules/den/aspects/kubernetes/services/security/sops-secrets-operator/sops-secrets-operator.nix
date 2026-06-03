# SOPS Secrets Operator — cluster-wide, age key at /var/lib/sops/age/key.
#
# Ported from main:modules/kubernetes/services/security/sops-secrets-operator/sops-secrets-operator.nix
{
  den.aspects.kubernetes.services.security.sops-secrets-operator = {
    crds =
      { inputs, system, ... }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.isindir.sops-secrets-operator;
      };

    k8s-manifests =
      { charts, ... }:
      {
        applications.sops-secrets-operator = {
          namespace = "sops-secrets-operator";

          helm.releases.sops = {
            chart = charts.isindir.sops-secrets-operator;

            values = {
              replicaCount = 1;

              # Watch all namespaces (cluster-wide secret management)
              namespaced = false;

              # Age key managed by agenix on all nodes
              secretsAsFiles = [
                {
                  name = "keys";
                  mountPath = "/var/lib/sops/age";
                  secretName = "sops-age-key-file";
                }
              ];

              extraEnv = [
                {
                  name = "SOPS_AGE_KEY_FILE";
                  value = "/var/lib/sops/age/key";
                }
              ];
            };
          };

          resources.ciliumNetworkPolicies = {
            allow-kube-apiserver-egress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                endpointSelector.matchLabels."app.kubernetes.io/instance" = "sops";
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
