# ArgoCD — OIDC via Kanidm, Gateway API HTTPRoute, service-domains quirk.
#
# Ported from main:modules/kubernetes/services/argocd/argocd.nix
{
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
  den.aspects.kubernetes.services.argocd = {
    service-domains = [ "argocd" ];

    age-secrets =
      { cluster, ... }:
      let
        environment = environments.${cluster.environment};
      in
      {
        age.secrets = {
          # Shares its rekeyFile AND generator with the kanidm OAuth2 client's
          # basicSecretFile (modules/den/aspects/services/security/kanidm.nix),
          # so both declarations of this secret resolve to the same value: the
          # one ArgoCD presents and the one Kanidm validates against.
          argocd-oidc-client-secret = {
            rekeyFile = environment.secretPath + "/oidc/argocd-oidc-client-secret.age";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
            sopsOutput.file = "oidc";
          };

          # No rekeyFile: these are pure generated secrets (stored in the
          # cluster's generatedSecretsDir), not rekeyed from a shared source.
          argocd-redis-secret = {
            generator.script = "alnum";
            sopsOutput.file = "argocd";
          };

          argocd-admin-pass = {
            generator.script = "passphrase";
            sopsOutput.file = "argocd";
          };

          argocd-admin-pass-mtime = {
            generator.script = "timestamp";
            sopsOutput.file = "argocd";
          };

          argocd-secret-key = {
            generator.script = "base64";
            sopsOutput.file = "argocd";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        ...
      }:
      let
        environment = environments.${cluster.environment};
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
            chart = charts.argoproj.argo-cd;

            values = {
              global = {
                inherit domain;
                revisionHistoryLimit = 3;
              };

              controller = {
                replicas = 1;
                # ServiceMonitors are authored as raw objects below: the chart
                # gates its own on .Capabilities, which offline helm template
                # never satisfies.
                metrics.enabled = true;
              };

              server = {
                replicas = 1;
                insecure = true;
                dnsConfig.options = [
                  {
                    name = "ndots";
                    value = "1";
                  }
                ];
                # ServiceMonitors are authored as raw objects below: the chart
                # gates its own on .Capabilities, which offline helm template
                # never satisfies.
                metrics.enabled = true;
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
                # ServiceMonitors are authored as raw objects below: the chart
                # gates its own on .Capabilities, which offline helm template
                # never satisfies.
                metrics.enabled = true;
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

          # See metrics.enabled comments: chart ServiceMonitors are
          # capabilities-gated and never render offline. Selectors match the
          # rendered metrics Services' app.kubernetes.io/name labels (the
          # controller's is the chart-quirky bare "argocd-metrics").
          objects =
            lib.mapAttrsToList
              (comp: serviceLabel: {
                apiVersion = "monitoring.coreos.com/v1";
                kind = "ServiceMonitor";
                metadata = {
                  name = "argocd-${comp}";
                  namespace = "argocd";
                };
                spec = {
                  selector.matchLabels."app.kubernetes.io/name" = serviceLabel;
                  endpoints = [ { port = "http-metrics"; } ];
                };
              })
              {
                application-controller = "argocd-metrics";
                server = "argocd-server-metrics";
                repo-server = "argocd-repo-server-metrics";
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
              stringData.auth = config.age.secrets.argocd-redis-secret.sopsRef;
            };

            secrets.argocd-secret.stringData = {
              "admin.password" = config.age.secrets.argocd-admin-pass.sopsRef;
              "admin.passwordMtime" = config.age.secrets.argocd-admin-pass-mtime.sopsRef;
              "server.secretkey" = config.age.secrets.argocd-secret-key.sopsRef;
              "oidc.clientSecret" = config.age.secrets.argocd-oidc-client-secret.sopsRef;
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
