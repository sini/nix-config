# Cert-Manager — DNS01 Cloudflare solver, Let's Encrypt ACME,
# dynamic ClusterIssuers from environment.certificates, wildcard certs per domain.
#
# Ported from main:modules/kubernetes/services/security/cert-manager/cert-manager.nix
{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mapAttrs'
    splitString
    take
    ;

  environments = config.den.environments;

  # Convert domain to k8s-safe resource name (last 2 parts, hyphenated)
  domainToResourceName =
    domain:
    let
      parts = splitString "." domain;
      topDomain = lib.reverseList (take 2 (lib.reverseList parts));
    in
    concatStringsSep "-" topDomain;
in
{
  den.aspects.kubernetes.cert-manager = {
    crds =
      { inputs, system, ... }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.jetstack.cert-manager;
        extraOpts = [
          "--set crds.enabled=true"
        ];
      };

    k8s-manifests =
      { cluster, ... }:
      let
        environment = environments.${cluster.environment};
        inherit (environment.certificates) domains issuers;
      in
      {
        applications.cert-manager = {
          namespace = "cert-manager";

          helm.releases.cert-manager = {
            chart = "jetstack/cert-manager";
            values = {
              global.leaderElection.namespace = "cert-manager";
              extraArgs = [
                "--dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53"
                "--dns01-recursive-nameservers-only"
              ];
              prometheus.enabled = false;
              prometheus.servicemonitor.enabled = false;
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
                    stringData.cloudflare-api-token = "\${sops:${issuer}-cloudflare-api-key}";
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
                  name = (domainToResourceName domain) + "-wildcard-certificate";
                  value = {
                    metadata = {
                      namespace = "certs";
                      annotations."cert-manager.io/issue-temporary-certificate" = "true";
                    };
                    spec = {
                      secretName = "${domainToResourceName domain}-wildcard-tls";
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
