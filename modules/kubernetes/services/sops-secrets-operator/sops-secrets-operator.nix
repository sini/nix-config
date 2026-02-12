{ lib, ... }:

{
  flake.kubernetes.services.sops-secrets-operator = {
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
            createNamespace = true;

            helm.releases.sops = {
              chart = charts.isindir.sops-secrets-operator;

              values = {
                # Configurable replica count
                replicaCount = config.kubernetes.services.sops-secrets-operator.replicaCount;

                # Watch all namespaces (cluster-wide secret management)
                namespaced = false;

                # We have our key managed by agenix in our modules/services/k3s/k3s.nix on all of our nodes
                extraVolumes = [
                  {
                    name = "sops-age";
                    hostPath = {
                      path = "/var/lib/sops/age";
                      type = "Directory";
                    };
                  }
                ];

                extraVolumeMounts = [
                  {
                    name = "sops-age";
                    mountPath = "/var/lib/sops/age";
                    readOnly = true;
                  }
                ];

                # Tell the operator pod where to read age keys.
                extraEnv = [
                  {
                    name = "SOPS_AGE_KEY_FILE";
                    value = "/var/lib/sops/age/key.txt";
                  }
                ];
              };
            };
          };
        };
      };
  };
}
