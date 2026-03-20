{
  clusters.bitstream = {
    environment = "dev";
    role = "k3s";

    networks = {
      control-plane = {
        cidr = "10.9.0.0/16";
        description = "Cluster control plane (VIP on management network)";
        assignments = {
          kube-apiserver-vip = "10.9.0.100";
        };
      };
      kubernetes-pods = {
        cidr = "172.16.0.0/16";
        ipv6_cidr = "fdfd:cafe:00:0002::/96";
        description = "Kubernetes pod network";
      };
      kubernetes-services = {
        cidr = "172.17.0.0/16";
        ipv6_cidr = "fdfd:cafe:00:8002::/112";
        description = "Kubernetes service network";
        assignments = {
          coredns = "172.17.0.10";
        };
      };
      kubernetes-loadbalancers = {
        cidr = "10.12.0.0/16";
        description = "LoadBalancer service IP range";
        assignments = {
          cilium-ingress-controller = "10.12.0.2";
          default-gateway = "10.12.0.1";
        };
      };
    };

    kubernetes = {
      tlsSanIps = [
        "10.9.1.1" # bitstream
        "10.9.1.2" # bitstream
      ];

      sso = {
        credentialsEnvironment = "prod";
        issuerPattern = "https://idm.json64.dev/oauth2/openid/{clientID}";
      };

      # Kubernetes services configuration
      services = {
        enabled = [
          "argocd"
          "cilium"
          "coredns"
          "sops-secrets-operator"
        ];
        config = {
          coredns.clusterIP = "172.17.0.10";

          sops-secrets-operator.replicaCount = 1; # High availability for prod
        };
      };
    };
  };
}
