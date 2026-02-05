{
  flake.kubernetes.services.argocd = {
    nixidy =
      { charts, ... }:
      {
        applications.argocd = {
          namespace = "argocd";

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
                secret.argocdServerAdminPassword = "$2y$10$VQgJvznVuhDbYveIvUsr1uKh0CgmBKbWP.DhKH2L5fr6e6SLBgP2i";
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
