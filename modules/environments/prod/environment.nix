{
  flake.environments.prod = {
    name = "prod";
    domain = "json64.dev";
    gatewayIp = "10.10.0.1";
    dnsServers = [
      "1.1.1.1"
      "8.8.8.8"
    ];

    networks = {
      management = {
        cidr = "10.10.10.0/24";
        purpose = "management";
        description = "Management network for infrastructure hosts";
      };
      kubernetes = {
        cidr = "172.20.0.0/16";
        purpose = "kubernetes-pods";
        description = "Kubernetes pod network";
      };
      services = {
        cidr = "172.21.0.0/16";
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

    monitoring = {
      scanEnvironments = [
        "prod"
        "dev"
      ];
    };
  };
}
