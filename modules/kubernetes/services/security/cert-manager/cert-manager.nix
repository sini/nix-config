{ lib, ... }:
{
  flake.kubernetes.services.cert-manager = {
    crds =
      {
        inputs,
        system,
        ...
      }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.jetstack.cert-manager;
        extraOpts = [
          "--set crds.enabled=true"
        ];
      };

    nixidy =
      {
        charts,
        environment,
        ...
      }:
      let
        # Consume certificate configuration from environment
        domains = environment.certificates.domains;
        issuers = environment.certificates.issuers;
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
            secrets =
              issuers
              |> lib.attrsets.mapAttrs' (
                issuer: secretRef: {
                  name = "${issuer}-secret";
                  value = {
                    type = "Opaque";
                    stringData.cloudflare-api-token = environment.secrets.from secretRef;
                  };
                }
              );

            clusterIssuers =
              issuers
              |> lib.attrsets.mapAttrs' (
                issuer: _secretRef: {
                  name = "${issuer}-issuer";
                  value = {
                    spec = {
                      acme = {
                        server = "https://acme-v02.api.letsencrypt.org./directory";
                        privateKeySecretRef = {
                          name = "${issuer}-issuer-account-key";
                        };
                        solvers = [
                          {
                            dns01 = {
                              cloudflare = {
                                apiTokenSecretRef = {
                                  name = "${issuer}-secret";
                                  key = "cloudflare-api-token";
                                };
                              };
                            };
                          }
                        ];
                      };
                    };
                  };
                }
              );

            certificates =
              domains
              |> lib.attrsets.mapAttrs' (
                domain: args: {
                  name = (environment.domainToResourceName domain) + "-wildcard-certificate";
                  value = {
                    metadata = {
                      namespace = "certs";
                      annotations."cert-manager.io/issue-temporary-certificate" = "true";
                    };
                    spec = {
                      secretName = "${environment.domainToResourceName domain}-wildcard-tls";
                      issuerRef = {
                        name = "${args.issuer}-issuer";
                        kind = "ClusterIssuer";
                      };
                      dnsNames = [
                        "${domain}"
                        "*.${domain}"
                      ];
                    };
                  };
                }
              );

            ciliumNetworkPolicies = {
              # Talk to letsencrypt, cloudflare, and external DNS.
              allow-world-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  endpointSelector.matchLabels = {
                    "app.kubernetes.io/instance" = "cert-manager";
                  };
                  egress = [
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
                            {
                              port = "853";
                              protocol = "UDP";
                            }
                          ];
                        }
                      ];
                    }
                  ];
                };
              };

              # Allow all cert-manager pods to access kube-apiserver
              allow-kube-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
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
  };
}
