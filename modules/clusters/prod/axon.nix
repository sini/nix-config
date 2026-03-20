{
  clusters.axon = {
    environment = "prod";
    role = "k3s";

    networks = {
      control-plane = {
        cidr = "10.10.10.0/24";
        description = "Cluster control plane (VIP on management network)";
        assignments = {
          kube-apiserver-vip = "10.10.10.100";
        };
      };
      kubernetes-pods = {
        cidr = "172.20.0.0/16";
        ipv6_cidr = "fdfd:cafe:00:0001::/96";
        description = "Kubernetes pod network";
      };
      kubernetes-services = {
        cidr = "172.21.0.0/16";
        ipv6_cidr = "fdfd:cafe:00:8001::/112";
        description = "Kubernetes service network";
        assignments = {
          coredns = "172.21.0.10";
        };
      };
      kubernetes-loadbalancers = {
        cidr = "10.11.0.0/16";
        description = "LoadBalancer service IP range";
        assignments = {
          cilium-ingress-controller = "10.11.0.2";
          default-gateway = "10.11.0.1";
        };
      };
    };

    kubernetes = {
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
  };
}
