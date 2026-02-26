{ rootPath, ... }:
{
  flake.environments.dev.kubernetes = {
    secretsFile = (rootPath + "/.secrets/env/dev/k8s-secrets.enc.yaml");

    kubeAPIVIP = "10.9.0.100";

    clusterCidr = "172.16.0.0/16";

    serviceCidr = "172.17.0.0/16";

    tlsSanIps = [
      "10.9.1.1" # bitstream
      "10.9.1.2" # bitstream
    ];

    loadBalancer = {
      cidr = "10.12.0.0/16";
      reservations = {
        cilium-ingress-controller = "10.12.0.2";
        gateway-controller = "10.12.0.1";
      };
    };

    # Kubernetes services configuration
    services = {
      enabled = [
        "argocd"
        "cilium"
        "sops-secrets-operator"
      ];
      config = {
        sops-secrets-operator.replicaCount = 1; # High availability for prod
      };
    };
  };
}
