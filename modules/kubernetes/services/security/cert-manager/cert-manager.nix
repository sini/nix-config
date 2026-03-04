{ self, lib, ... }:
let
  inherit (self.lib.kubernetes-utils) domainToResourceName;
in
{
  flake.kubernetes.services.cert-manager = {
    crds =
      { inputs, system, ... }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.jetstack.cert-manager;
        extraOpts = [
          "--set crds.enabled=true"
        ];
      };

    options = {
      domains = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              issuer = lib.mkOption {
                type = lib.types.str;
                description = "The API key name to use for this domain";
              };
            };
          }
        );
        default = { };
        description = "Domains to generate certs for";
      };

      issuers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              sopsFile = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = "Optional path to the file containing the API key";
              };
              secretKey = lib.mkOption {
                type = lib.types.str;
                description = "The secret key name";
              };
            };
          }
        );
        default = { };
        description = "API key configurations";
      };
    };

    nixidy =
      {
        config,
        charts,
        secrets,
        ...
      }:
      let
        domains = config.kubernetes.services.cert-manager.domains;
        issuers = config.kubernetes.services.cert-manager.issuers;
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
                    stringData.cloudflare-api-token = secrets.from secretRef;
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
