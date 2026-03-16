{
  flake.environments.prod.kubernetes = {
    tlsSanIps = [
      "10.10.10.2" # axon-01 external
      "10.10.10.3" # axon-02 external
      "10.10.10.4" # axon-03 external
    ];

    # Kubernetes services configuration
    services = {
      enabled = [
        # Core Infra
        "cilium"
        "coredns"
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
        "longhorn"
        # "rook-ceph"
      ];
      config = {
        cilium = {
          devices = [
            "lo"
            "enp2s0"
            "enp199s0f5"
            "enp199s0f6"
            # "tailscale0"
          ];
          # directRoutingDevice = "enp199+";
          directRoutingDevice = "*";
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
