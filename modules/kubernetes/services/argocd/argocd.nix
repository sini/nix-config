{
  flake.kubernetes.services.argocd = {
    nixidy =
      {
        charts,
        secrets,
        ...
      }:
      {
        applications.argocd = {
          namespace = "argocd";

          createNamespace = true;

          # Adoption-safe sync options
          syncPolicy = {
            autoSync = {
              enable = true;
              prune = true;
              selfHeal = true;
            };
            syncOptions = {
              serverSideApply = true;
              applyOutOfSyncOnly = true;
              createNamespace = false;
            };
          };

          # Sync wave: ArgoCD at -1 (infrastructure component)
          # Must be operational before managing other applications
          annotations."argocd.argoproj.io/sync-wave" = "-1";

          helm.releases.argocd = {
            chart = charts.argoproj.argo-cd;

            values = {
              global = {
                # Local dev: single replica for all components
                revisionHistoryLimit = 3;
              };

              # Application Controller
              controller = {
                replicas = 1;
              };

              # API Server - insecure mode for kubectl port-forward
              server = {
                replicas = 1;
                # Disable TLS on server (use port-forward for local dev)
                insecure = true;
                # DNS config for proper resolution
                dnsConfig.options = [
                  {
                    name = "ndots";
                    value = "1";
                  }
                ];
              };

              # Repository Server
              repoServer = {
                replicas = 1;
                # DNS config for proper resolution
                dnsConfig.options = [
                  {
                    name = "ndots";
                    value = "1";
                  }
                ];
                readinessProbe.timeoutSeconds = 60;
                livenessProbe.timeoutSeconds = 60;

              };

              # Redis (for caching)
              redis = {
                enabled = true;
              };

              # Disable HA redis for local dev
              redis-ha.enabled = false;

              # Disable the redis-secret-init Job hook
              # The Job has no hook-weight annotations, causing kluctl to apply it before
              # its ServiceAccount dependency. We provide the redis secret ourselves below.
              redisSecretInit.enabled = false;

              # ApplicationSet Controller
              applicationSet = {
                replicas = 1;
              };

              # Notifications Controller
              notifications = {
                enabled = false; # Disable for local dev
              };

              # Dex (OIDC) - disable for local dev
              dex.enabled = false;

              configs = {
                params = {
                  "server.insecure" = true;
                };
                # RBAC: allow admin to do everything
                rbac = {
                  "policy.default" = "role:admin";
                };
                cm."resource.exclusions" = ''
                  - apiGroups:
                    - cilium.io
                    kinds:
                      - CiliumIdentity
                    clusters:
                      - "*"
                '';
              };
              global.networkPolicy.create = true;
            };
          };
          resources = {
            secrets.argocd-redis = {
              type = "Opaque";
              stringData.auth = secrets.for "argocd-redis";
            };

            secrets.argocd-secret.stringData = {
              "admin.password" = secrets.for "argocd-admin-password";
              "admin.passwordMtime" = secrets.for "argocd-admin-mtime";
              "server.secretkey" = secrets.for "argocd-secretkey";
            };

            # Allow ingress traffic from traefik to
            # argocd-server.
            # networkPolicies.allow-traefik-ingress.spec = {
            #   podSelector.matchLabels."app.kubernetes.io/name" = "argocd-server";
            #   policyTypes = [ "Ingress" ];
            #   ingress = [
            #     {
            #       from = [
            #         {
            #           namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "traefik";
            #           podSelector.matchLabels."app.kubernetes.io/name" = "traefik";
            #         }
            #       ];
            #       ports = [
            #         {
            #           protocol = "TCP";
            #           port = 8080;
            #         }
            #       ];
            #     }
            #   ];
            # };

            ciliumNetworkPolicies = {
              # Allow argocd-repo-server egress access to github.com
              allow-github-egress.spec = {
                endpointSelector.matchLabels."app.kubernetes.io/name" = "argocd-repo-server";
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
                  # Allow HTTPS to github.com
                  {
                    toFQDNs = [
                      { matchName = "github.com"; }
                    ];
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

              # Allow all ArgoCD pods to access kube-apiserver
              allow-kube-apiserver-egress.spec = {
                endpointSelector.matchLabels."app.kubernetes.io/part-of" = "argocd";
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

            # ciliumClusterwideNetworkPolicies = {
            #   # Allow all cilium endpoints to talk egress to each other
            #   allow-internal-egress.spec = {
            #     description = "Policy to allow all Cilium managed endpoint to talk to all other cilium managed endpoints on egress";
            #     endpointSelector.matchLabels."app.kubernetes.io/part-of" = "argocd";
            #     ingress = [
            #       {
            #         fromEndpoints = [ { } ];
            #       }
            #     ];
            #   };
            # };
          };

          # resources = {
          #   ingressRoutes = {
          #     argocd-dashboard-route.spec = {
          #       entryPoints = [
          #         "websecure"
          #       ];
          #       routes = [
          #         {
          #           match = "Host(`argo.sinistar.io`)";
          #           kind = "Rule";
          #           services = [
          #             {
          #               name = "argocd-server";
          #               namespace = "argocd";
          #               port = 80;
          #             }
          #           ];
          #         }
          #       ];
          #       tls.secretName = "anderwersede-tls-certificate";
          #     };
          #   };
          # };
        };
      };
  };
}
