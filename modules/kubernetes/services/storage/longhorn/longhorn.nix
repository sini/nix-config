# This module should work, but I'm not using it -- leaving for posterity
{
  flake.kubernetes.services.longhorn = {
    crds =
      {
        inputs,
        system,
        ...
      }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.longhorn.longhorn;
        namePrefix = "longhorn";
      };

    nixidy =
      {
        charts,
        environment,
        ...
      }:
      let
        longhornDomain = environment.getDomainFor "longhorn";
      in
      {
        applications.longhorn = {
          namespace = "longhorn-system";

          syncPolicy = {
            syncOptions = {
              serverSideApply = true;
            };
          };

          compareOptions.serverSideDiff = true;

          helm.releases.longhorn = {
            chart = charts.longhorn.longhorn;
            values = {

              longhorn.preUpgradeChecker.jobEnabled = false;

              preUpgradeChecker.upgradeVersionCheck = false;

              defaultSettings = {
                createDefaultDiskLabeledNodes = true;
                defaultDataPath = "/var/lib/longhorn";
                backupstorePollInterval = 300;
                replicaSoftAntiAffinity = true;
                replicaAutoBalance = "best-effort";
                # backupTarget = ;
                # backupTargetCredentialSecret = "longhorn-backup";
              };

              persistence = {
                defaultClass = true;
                defaultClassReplicaCount = 2;
                reclaimPolicy = "Retain";
              };

              longhornUI.replicas = 1;

              # csi = {
              #   attacherReplicas = 3;
              #   provisionerReplicas = 3;
              #   resizerReplicas = 3;
              #   snapshotterReplicas = 3;
              #   tolerations = [
              #     {
              #       key = "node-role.kubernetes.io/control-plane";
              #       operator = "Exists";
              #       effect = "NoSchedule";
              #     }
              #     {
              #       key = "node-role.kubernetes.io/master";
              #       operator = "Exists";
              #       effect = "NoSchedule";
              #     }
              #     {
              #       key = "CriticalAddonsOnly";
              #       operator = "Exists";
              #     }
              #   ];
              # };

            };
          };

          resources = {
            httpRoutes.rook-ceph-dashboard.spec = {
              hostnames = [ longhornDomain ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${environment.domainToResourceName longhornDomain}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "longhorn-frontend";
                      port = 80;
                    }
                  ];
                }
              ];
            };

            # Allow csi-driver-nfs access to kube-apiserver
            ciliumNetworkPolicies.allow-kube-apiserver-egress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Allow snapshot controller to talk to kube-apiserver.";
                endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "longhorn-system";
                # endpointSelector.matchExpressions = [
                #   {
                #     key = "app";
                #     operator = "In";
                #     values = [
                #       "rook-ceph-operator"
                #       "rook-discover"
                #       "rook-ceph-detect-version"
                #     ];
                #   }
                # ];
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
}
