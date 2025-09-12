{
  flake.environments.dev = {
    name = "dev";
    domain = "sinistar.io";
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
        cidr = "172.16.0.0/16";
        purpose = "kubernetes-pods";
        description = "Kubernetes pod network";
      };
      services = {
        cidr = "172.17.0.0/16";
        purpose = "kubernetes-services";
        description = "Kubernetes service network";
      };
      loadbalancer = {
        cidr = "10.12.0.0/16";
        purpose = "loadbalancer";
        description = "LoadBalancer service IP range";
      };
    };

    kubernetes = {
      clusterCidr = "172.16.0.0/16";
      serviceCidr = "172.17.0.0/16";
      tlsSanIps = [
        "10.10.10.5" # axon-01 external
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

    delegation = {
      metricsTo = "prod";
      authTo = "prod";
      logsTo = "prod";
    };
  };
}
