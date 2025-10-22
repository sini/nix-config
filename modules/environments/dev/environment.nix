{
  flake.environments.dev = {
    name = "dev";
    domain = "dev.json64.dev";
    gatewayIp = "10.9.0.1";
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
        cidr = "10.9.0.0/16";
        ipv6_cidr = "fd64:1:1::/64";
        purpose = "management";
        description = "Management network for infrastructure hosts";
      };
      kubernetes = {
        cidr = "172.16.0.0/16";
        ipv6_cidr = "fd64:1:2::/64";
        purpose = "kubernetes-pods";
        description = "Kubernetes pod network";
      };
      services = {
        cidr = "172.17.0.0/16";
        ipv6_cidr = "fd64:1:3::/64";
        purpose = "kubernetes-services";
        description = "Kubernetes service network";
      };
      loadbalancer = {
        cidr = "10.12.0.0/16";
        purpose = "loadbalancer";
        description = "LoadBalancer service IP range";
      };
    };

    # IPv6 ULA configuration for dev environment
    ipv6 = {
      ula_prefix = "fd64:1::/48";
      management_prefix = "fd64:1:1::/64";
      kubernetes_prefix = "fd64:1:2::/64";
      services_prefix = "fd64:1:3::/64";
    };

    kubernetes = {
      clusterCidr = "172.16.0.0/16";
      serviceCidr = "172.17.0.0/16";
      tlsSanIps = [
        "10.9.1.1" # axon-01 external
      ];
      loadBalancerRange = "10.12.0.0/16";
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
      environment = "dev";
      owner = "json64";
    };

    users = {
      sini = { };
      shuo = { };
      will = { };
      media = { };
    };

    # delegation = {
    #   metricsTo = "prod";
    #   authTo = "prod";
    #   logsTo = "prod";
    # };
  };
}
