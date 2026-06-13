# Cert-Manager — DNS01 Cloudflare solver, Let's Encrypt ACME,
# dynamic ClusterIssuers from environment.certificates, wildcard certs per domain.
#
# Ported from main:modules/kubernetes/services/security/cert-manager/cert-manager.nix
{
  lib,
  ...
}:
let
  inherit (lib)
    flatten
    listToAttrs
    mapAttrs'
    mapAttrsToList
    optional
    ;
in
{
  den.aspects.kubernetes.services.security.cert-manager = {
    crds =
      { inputs, system, ... }:
      {
        name = "cert-manager";
        chart = inputs.nixhelm.chartsDerivations.${system}.jetstack.cert-manager;
        extraOpts = [
          "--set crds.enabled=true"
        ];
      };

    age-secrets =
      { environment, ... }:
      {
        # One cloudflare-api-token secret per issuer. Shares its rekeyFile with
        # the host-side acme declaration (modules/den/aspects/services/security/
        # acme.nix); re-exported here to the cluster sops file for vals to
        # resolve. Real external tokens — no generator.
        age.secrets = listToAttrs (
          flatten (
            mapAttrsToList (
              issuerName: issuerConfig:
              optional (issuerConfig.ageKeyFile != null) {
                name = "${issuerName}-cloudflare-api-key";
                value = {
                  rekeyFile = issuerConfig.ageKeyFile;
                  sopsOutput = {
                    file = "cert-manager";
                    key = "${issuerName}-cloudflare-api-key";
                  };
                };
              }
            ) environment.certificates.issuers
          )
        );
      };

    k8s-manifests =
      {
        config,
        cluster,
        environment,
        charts,
        ...
      }:
      let
        inherit (environment.certificates) domains issuers;
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

              # Controller metrics + ServiceMonitor (note: lowercase
              # `servicemonitor` is the chart's spelling).
              prometheus = {
                enabled = true;
                servicemonitor.enabled = true;
              };
            };
          };

          resources = {
            secrets =
              issuers
              |> mapAttrs' (
                issuer: _secretRef: {
                  name = "${issuer}-secret";
                  value = {
                    type = "Opaque";
                    stringData.cloudflare-api-token = config.age.secrets."${issuer}-cloudflare-api-key".sopsRef;
                  };
                }
              );

            clusterIssuers =
              issuers
              |> mapAttrs' (
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
              |> mapAttrs' (
                domain: args: {
                  name = (cluster.resourceForDomain domain) + "-wildcard-certificate";
                  value = {
                    metadata = {
                      namespace = "certs";
                      annotations."cert-manager.io/issue-temporary-certificate" = "true";
                    };
                    spec = {
                      secretName = "${cluster.resourceForDomain domain}-wildcard-tls";
                      issuerRef = {
                        name = "${args.issuer}-issuer";
                        kind = "ClusterIssuer";
                      };
                      dnsNames = [
                        domain
                        "*.${domain}"
                      ];
                    };
                  };
                }
              );

            ciliumNetworkPolicies = {
              # Talk to letsencrypt, cloudflare, and external DNS
              allow-world-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  endpointSelector.matchLabels."app.kubernetes.io/instance" = "cert-manager";
                  egress = [
                    {
                      toEntities = [ "world" ];
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

              # Allow cert-manager pods to access kube-apiserver
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
