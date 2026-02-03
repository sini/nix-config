{ charts, ... }:
{
  applications.sops-secrets-operator = {
    namespace = "sops-operator";
    createNamespace = true;

    helm.releases.sops = {
      chart = charts.isindir.sops-secrets-operator;

      values = {
        # Single replica for simplicity
        replicaCount = 1;

        # Watch all namespaces (cluster-wide secret management)
        namespaced = false;

        # # Mount secret with age keys to operator pod.
        # secretsAsFiles = [
        #   {
        #     name = "sops-age-key-file";
        #     mountPath = "/var/lib/sops/age";
        #     secretName = "sops-age-key-file";
        #   }
        # ];

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
}
