{
  flake.environments.dev.kubernetes = {
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
}
