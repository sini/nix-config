{ rootPath, ... }:
{
  flake.environments.prod.kubernetes = {
    secretsFile = (rootPath + "/.secrets/env/prod/k8s-secrets.enc.yaml");

    kubeAPIVIP = "10.10.10.100";

    clusterCidr = "172.20.0.0/16";
    serviceCidr = "172.21.0.0/16";

    tlsSanIps = [
      "10.10.10.2" # axon-01 external
      "10.10.10.3" # axon-02 external
      "10.10.10.4" # axon-03 external
      "172.16.255.1" # axon-01 internal
      "172.16.255.2" # axon-02 internal
      "172.16.255.3" # axon-03 internal
    ];

    loadBalancer = {
      cidr = "10.11.0.0/16";
      reservations = {
        cilium-ingress-controller = "10.11.0.1";
      };
    };

    # Kubernetes services configuration
    services = {
      enabled = [
        "argocd"
        "cert-manager"
        "cilium"
        "cilium-bgp"
        "sops-secrets-operator"
      ];
      config = {
        cilium = {
          devices = [
            "br0"
            # "enp199s0f5"
            # "enp199s0f6"
            # "br0"
            # "enp2s0"
            # "tailscale0"
          ];
          directRoutingDevice = "br0";
        };
        sops-secrets-operator.replicaCount = 1; # High availability for prod
      };
    };
  };
}
