{
  flake.kubernetes.services.cert-manager = {
    crds =
      { pkgs, lib, ... }:
      let
        # nix run nixpkgs#nix-prefetch-github -- cert-manager cert-manager --rev v1.19.3
        src = pkgs.fetchFromGitHub {
          owner = "cert-manager";
          repo = "cert-manager";
          rev = "v1.19.3";
          hash = "sha256-XsGNcIv23YLLC4tY6MttPRhQDhf7SeaOMub/ZY+p7t0=";
        };
        crds =
          let
            path = "deploy/crds/";
          in
          lib.pipe (builtins.readDir "${src}/${path}") [
            (lib.filterAttrs (_name: type: type == "regular"))
            (lib.filterAttrs (name: _type: lib.hasSuffix ".yaml" name))
            builtins.attrNames
            (map (file: "${path}/${file}"))
          ];
      in
      {
        inherit src crds;
      };

    nixidy =
      {
        environment,
        charts,
        secrets,
        ...
      }:
      let
        namespaceList = [
          "argocd"
          "kube-system"
        ];
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
                # "${environment.domain}"
                "*.${environment.domain}"
              ];
            };
          };
        }) namespaceList;
      in
      {
        applications.cert-manager = {
          namespace = "cert-manager";

          helm.releases.cert-manager = {
            chart = charts.jetstack.cert-manager;
            values = {
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
              stringData.cloudflare-api-token = secrets.for "cloudflare-api-token";
            };

            clusterIssuers."cloudflare-issuer" = {
              metadata = {
                name = "cloudflare-issuer";
                namespace = "cert-manager";
              };
              spec = {
                acme = {
                  server = "https://acme-v02.api.letsencrypt.org./directory";
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
            ciliumNetworkPolicies = {
              allow-world-egress.spec = {
                endpointSelector.matchLabels = {
                  "app.kubernetes.io/instance" = "cert-manager";
                };
                egress = [
                  # Enable DNS proxying
                  {
                    toEndpoints = [
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "kube-system";
                          "k8s:k8s-app" = "kube-dns";
                        };
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "53";
                            protocol = "ANY";
                          }
                        ];
                        rules.dns = [
                          { matchPattern = "*"; }
                        ];
                      }
                    ];
                  }
                  {
                    toEntities = [
                      "world"
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "443";
                            protocol = "TCP";
                          }
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
              allow-kube-apiserver-egress.spec = {
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

  };
}
