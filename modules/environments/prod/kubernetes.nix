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
        cilium-ingress-controller = "10.11.0.2";
        gateway-controller = "10.11.0.1";
      };
    };

    # Kubernetes services configuration
    services = {
      enabled = [
        # Core Infra
        "cilium"
        "sops-secrets-operator"

        ## Internal services
        "argocd"
        "hubble-ui"

        # Gateway/Ingress
        "cilium-bgp"
        "cert-manager"
        "envoy-gateway"

        # Node Features
        "amd-gpu-device-plugin"

        # Storage drivers
        "volume-snapshots"
        "csi-driver-nfs"
      ];
      config = {
        coredns.clusterIP = "172.21.0.10";
        cert-manager = {
          domains = {
            "json64.dev" = {
              issuer = "json64-dev";
            };
          };
          issuers = {
            "json64-dev" = {
              sopsFile = (rootPath + "/.secrets/env/prod/k8s-secrets.enc.yaml");
              secretKey = "cloudflare-api-token";
            };
          };
        };
        cilium = {
          devices = [
            "br0" # "enp2s0"
            # "enp199s0f5"
            # "enp199s0f6"
            # "tailscale0"
          ];
          directRoutingDevice = "br0";
        };
        csi-driver-nfs.volumes = {
          "vault-nfs" = {
            server = "10.10.10.10";
            share = "/volume2/data";
          };
        };
        sops-secrets-operator.replicaCount = 1; # High availability for prod
      };
    };
  };
}
