{
  flake.kubernetes.services.cert-manager = {
    crds =
      { pkgs, ... }:
      {
        # nix run nixpkgs#nix-prefetch-github -- cert-manager cert-manager --rev v1.19.3
        src = pkgs.fetchFromGitHub {
          owner = "cert-manager";
          repo = "cert-manager";
          rev = "v1.19.3";
          hash = "sha256-XsGNcIv23YLLC4tY6MttPRhQDhf7SeaOMub/ZY+p7t0=";
        };
        crds = [
          "deploy/crds/cert-manager.io_certificaterequests.yaml"
          "deploy/crds/cert-manager.io_certificates.yaml"
          "deploy/crds/cert-manager.io_clusterissuers.yaml"
          "deploy/crds/cert-manager.io_issuers.yaml"
          "deploy/crds/acme.cert-manager.io_challenges.yaml"
          "deploy/crds/acme.cert-manager.io_orders.yaml"
        ];
      };

    nixidy =
      {
        config,
        environment,
        charts,
        lib,
        secrets,
        ...
      }:
      let
        namespaceList = lib.unique (map (app: app.namespace) (builtins.attrValues config.applications));
        certificatesResources = map (namespace: {
          name = "${namespace}-wildcard-certificate";
          value = {
            metadata = {
              name = "wildcard-certificate";
              namespace = namespace;
              annotations = {
                "cert-manager.io/issue-temporary-certificate" = "true";
              };
            };
            spec = {
              secretName = "wildcard-tls";
              issuerRef = {
                name = "cloudflare-issuer";
                kind = "ClusterIssuer";
              };
              dnsNames = [
                "${environment.domain}"
                "*.${environment.domain}"
              ];
            };
          };
        }) namespaceList;
      in
      {
        applications.cert-manager = {
          namespace = "cert-manager";
          createNamespace = true;

          helm.releases.cert-manager = {
            chart = charts.jetstack.cert-manager;
            includeCRDs = true;

            values = {
              crds.enabled = true;
              global.leaderElection.namespace = "cert-manager";
              extraArgs = [
                "--dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53"
                "--dns01-recursive-nameservers-only"
              ];
              # dns01RecursiveNameservers = concatStringsSep "," [
              #   "https://1.1.1.1:443/dns-query"
              #   "https://1.0.0.1:443/dns-query"
              # ];
              # dns01RecursiveNameserversOnly = true;

              prometheus.enabled = false; # TODO: monitoring...
              prometheus.servicemonitor.enabled = false;
            };
          };

          resources = {
            secrets.cloudflare-api-token = {
              metadata.namespace = "cert-manager";
              type = "Opaque";
              stringData.auth = secrets.for "cloudflare-api-token";
            };

            clusterIssuers."cloudflare-issuer" = {
              metadata = {
                name = "cloudflare-issuer";
                namespace = "cert-manager";
              };
              spec = {
                acme = {
                  server = "https://acme-v02.api.letsencrypt.org/directory";
                  privateKeySecretRef = {
                    name = "cloudflare-issuer-account-key";
                  };
                  solvers = [
                    {
                      dns01 = {
                        cloudflare = {
                          apiTokenSecretRef = {
                            name = "cloudflare-api-token";
                            key = "cloudflare-api-token";
                          };
                        };
                      };
                    }
                  ];
                };
              };
            };

            certificates = builtins.listToAttrs certificatesResources;

            # Allow all cert-manager pods to access kube-apiserver
            ciliumNetworkPolicies.allow-kube-apiserver-egress.spec = {
              endpointSelector.matchLabels."app.kubernetes.io/instance" = "cert-manager";
              egress = [
                {
                  toEntities = [ "kube-apiserver" ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "6443";
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };
          };
        };
      };

  };
}
