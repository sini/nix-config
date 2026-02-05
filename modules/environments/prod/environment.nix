{
  flake.environments.prod = {
    id = 1;
    domain = "json64.dev";
    gatewayIp = "10.10.0.1";
    gatewayIpV6 = "fe80::962a:6fff:fef2:cf4d";
    dnsServers = [
      # Cloudflare
      "1.1.1.1"
      "2606:4700:4700::1111"
      "1.0.0.1"
      "2606:4700:4700::1001"

      # Public Nat64 -- https://nat64.net
      "2a01:4f8:c2c:123f::1"
      "2a00:1098:2b::1"
    ];

    networks = {
      management = {
        cidr = "10.10.10.0/16";
        ipv6_cidr = "fd64:0:1::/64";
        purpose = "management";
        description = "Management network for infrastructure hosts";
      };
      kubernetes = {
        cidr = "172.20.0.0/16";
        ipv6_cidr = "fd64:0:2::/64";
        purpose = "kubernetes-pods";
        description = "Kubernetes pod network";
      };
      services = {
        cidr = "172.21.0.0/16";
        ipv6_cidr = "fd64:0:3::/64";
        purpose = "kubernetes-services";
        description = "Kubernetes service network";
      };
      mesh = {
        cidr = "172.16.255.0/24";
        purpose = "kubernetes-internal";
        description = "Internal mesh network for Kubernetes nodes";
      };
      loadbalancer = {
        cidr = "10.11.0.0/16";
        purpose = "loadbalancer";
        description = "LoadBalancer service IP range";
      };
    };

    # IPv6 ULA configuration
    ipv6 = {
      ula_prefix = "fd64::/48";
      management_prefix = "fd64:0:1::/64";
      kubernetes_prefix = "fd64:0:2::/64";
      services_prefix = "fd64:0:3::/64";
      # External ISP prefix for NPTv6 translation (placeholder)
      external_prefix = "2001:5a8:608c:4a00::/64";
    };

    kubernetes = {
      clusterCidr = "172.20.0.0/16";
      serviceCidr = "172.21.0.0/16";
      internalMeshCidr = "172.16.255.0/24";
      tlsSanIps = [
        "10.10.10.2" # axon-01 external
        "10.10.10.3" # axon-02 external
        "10.10.10.4" # axon-03 external
        "172.16.255.1" # axon-01 internal
        "172.16.255.2" # axon-02 internal
        "172.16.255.3" # axon-03 internal
      ];
      loadBalancerRange = "10.11.0.0/16";

      # Kubernetes services configuration
      services = {
        argocd = { };
        cilium = { };
        # romm = { };
        sops-secrets-operator = {
          replicaCount = 2; # High availability for prod
        };
      };
    };

    email = {
      domain = "json64.dev";
      adminEmail = "jason@json64.dev";
    };

    acme = {
      server = "https://acme-v02.api.letsencrypt.org/directory";
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
    };

    timezone = "America/Los_Angeles";

    location = {
      country = "US";
      region = "us-west";
    };

    tags = {
      environment = "prod";
      owner = "json64";
    };

    users = {
      sini = { };
      shuo = { };
      will = { };
      media = { };
    };

    monitoring = {
      scanEnvironments = [
        "prod"
        "dev"
      ];
    };
  };
}
