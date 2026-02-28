{ lib, ... }:
{
  flake.kubernetes.services.sops-secrets-operator = {
    crds =
      { inputs, system, ... }:
      {
        src = inputs.nixhelm.chartsDerivations.${system}.isindir.sops-secrets-operator;
        crds = [ "crds/isindir.github.com_sopssecrets.yaml" ];
      };

    # Option declarations for environment-level configuration
    options = {
      replicaCount = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Number of replicas for the sops-secrets-operator";
      };
    };

    nixidy =
      {
        config,
        charts,
        ...
      }:
      {
        config = {
          applications.sops-secrets-operator = {
            namespace = "sops-secrets-operator";

            helm.releases.sops = {
              chart = charts.isindir.sops-secrets-operator;

              values = {
                # Configurable replica count
                replicaCount = config.kubernetes.services.sops-secrets-operator.replicaCount;

                # Watch all namespaces (cluster-wide secret management)
                namespaced = false;

                # We have our key managed by agenix in our modules/services/k3s/k3s.nix on all of our nodes
                secretsAsFiles = [
                  {
                    name = "keys";
                    mountPath = "/var/lib/sops/age";
                    secretName = "sops-age-key-file";
                  }
                ];

                # Tell the operator pod where to read age keys.
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
  };
}
