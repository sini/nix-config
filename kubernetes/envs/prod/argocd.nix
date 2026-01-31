{ charts, ... }:
{
  applications.argocd = {
    namespace = "argocd";

    helm.releases.argocd = {
      chart = charts.argoproj.argo-cd;

      values = {
        configs = {
          secret.argocdServerAdminPassword = "$2y$10$VQgJvznVuhDbYveIvUsr1uKh0CgmBKbWP.DhKH2L5fr6e6SLBgP2i";
          cm."resource.exclusions" = ''
            - apiGroups:
              - cilium.io
              kinds:
                - CiliumIdentity
              clusters:
                - "*"
          '';
          params."server.insecure" = "true";
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
}
