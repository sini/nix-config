# ArgoCD — OIDC via Kanidm, Gateway API HTTPRoute, service-domains quirk.
#
# Ported from main:modules/kubernetes/services/argocd/argocd.nix
{
  den,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    splitString
    take
    ;

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
  den.aspects.kubernetes.argocd = {
    service-domains = [ "argocd" ];

    k8s-manifests =
      { cluster, ... }:
      let
        environment = config.den.environments.${cluster.environment};
        domain = environment.getDomainFor "argocd";

        # OIDC issuer URL via Kanidm
        oidcIssuerUrl =
          let
            kanidmDomain = environment.getDomainFor "kanidm";
          in
          "https://${kanidmDomain}/oauth2/openid/argocd";
      in
      {
        applications.argocd = {
          namespace = "argocd";

          syncPolicy = {
            syncOptions = {
              clientSideApplyMigration = false;
              serverSideApply = true;
            };
          };

          annotations."argocd.argoproj.io/sync-wave" = "-1";

          compareOptions.serverSideDiff = true;

          helm.releases.argocd = {
            chart = "argoproj/argo-cd";

            values = {
              global = {
                inherit domain;
                revisionHistoryLimit = 3;
              };

              controller.replicas = 1;

              server = {
                replicas = 1;
                insecure = true;
                dnsConfig.options = [
                  {
                    name = "ndots";
                    value = "1";
                  }
                ];
              };

              repoServer = {
                replicas = 1;
                dnsConfig.options = [
                  {
                    name = "ndots";
                    value = "1";
                  }
                ];
                readinessProbe.timeoutSeconds = 60;
                livenessProbe.timeoutSeconds = 60;
              };

              redis.enabled = true;
              redis-ha.enabled = false;
              redisSecretInit.enabled = false;

              applicationSet.replicas = 1;

              notifications.enabled = false;
              dex.enabled = false;

              configs = {
                params."server.insecure" = true;

                cm = {
                  "admin.enabled" = false;

                  "resource.exclusions" = ''
                    - apiGroups:
                      - cilium.io
                      kinds:
                        - CiliumIdentity
                      clusters:
                        - "*"
                  '';

                  "oidc.config" = builtins.toJSON {
                    name = "kanidm";
                    issuer = oidcIssuerUrl;
                    clientID = "argocd";
                    clientSecret = "$oidc.clientSecret";
                    enablePKCEAuthentication = true;
                    requestedScopes = [
                      "email"
                      "openid"
                      "profile"
                    ];
                    requestedIDTokenClaims.groups.essential = true;
                  };
                };

                rbac = {
                  "policy.default" = "role:readonly";
                  "policy.csv" = ''
                    g, admin, role:admin
                    g, user, role:readonly
                  '';
                  scopes = "[groups]";
                };
              };

              global.networkPolicy.create = true;
            };
          };

          resources = {
            httpRoutes.argocd-server.spec = {
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${domainToResourceName domain}-https";
                }
              ];
              hostnames = [ domain ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "argocd-server";
                      port = 80;
                    }
                  ];
                }
              ];
            };

            secrets.argocd-redis = {
              type = "Opaque";
              stringData.auth = "\${sops:argocd-redis-secret}";
            };

            secrets.argocd-secret.stringData = {
              "admin.password" = "\${sops:argocd-admin-pass}";
              "admin.passwordMtime" = "\${sops:argocd-admin-pass-mtime}";
              "server.secretkey" = "\${sops:argocd-secret-key}";
              "oidc.clientSecret" = "\${sops:argocd-oidc-client-secret}";
            };

            ciliumNetworkPolicies = {
              # Allow argocd egress to github.com and IDM
              allow-external-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  endpointSelector.matchLabels."app.kubernetes.io/part-of" = "argocd";
                  egress = [
                    # DNS proxying
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
                            {
                              port = "853";
                              protocol = "ANY";
                            }
                          ];
                          rules.dns = [
                            { matchPattern = "*"; }
                          ];
                        }
                      ];
                    }
                    # HTTPS to github.com and IDM
                    {
                      toEntities = [ "world" ];
                      toPorts = [
                        {
                          ports = [
                            {
                              port = "443";
                              protocol = "TCP";
                            }
                          ];
                        }
                      ];
                    }
                  ];
                };
              };

              # Allow ArgoCD pods to access kube-apiserver
              allow-kube-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  endpointSelector.matchLabels."app.kubernetes.io/part-of" = "argocd";
                  egress = [
                    {
                      toEntities = [ "kube-apiserver" ];
                      toPorts = [
                        {
                          ports = [
                            {
                              port = "443";
                              protocol = "TCP";
                            }
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
