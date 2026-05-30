# CSI Driver NFS — dynamic StorageClasses per NFS volume via
# kubernetes-csi/csi-driver-nfs Helm chart, proto=tcp nfsvers=4.1 noatime,
# CiliumNetworkPolicy.
#
# Ported from main:modules/kubernetes/services/storage/csi-driver-nfs/csi-driver-nfs.nix
{
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.kubernetes.csi-driver-nfs = {
    crds =
      { inputs, system, ... }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.kubernetes-csi.csi-driver-nfs;
      };

    k8s-manifests =
      { cluster, charts, ... }:
      let
        environment = environments.${cluster.environment};
        inherit (environment) nfsVolumes;
      in
      {
        applications.csi-driver-nfs = {
          namespace = "csi-nfs";

          helm.releases.csi-driver-nfs = {
            chart = charts.kubernetes-csi.csi-driver-nfs;
          };

          resources = {
            storageClasses = lib.mapAttrs (_volumeName: volumeConfig: {
              provisioner = "nfs.csi.k8s.io";
              reclaimPolicy = "Retain";
              volumeBindingMode = "Immediate";
              allowVolumeExpansion = true;

              parameters = {
                inherit (volumeConfig) server;
                inherit (volumeConfig) share;
                subDir = "\${pvc.metadata.namespace}/\${pvc.metadata.name}/\${pv.metadata.name}";
              };

              mountOptions = [
                "proto=tcp"
                "noresvport"
                "nfsvers=4.1"
                "noauto"
                "noatime"
              ];
            }) nfsVolumes;

            ciliumNetworkPolicies.allow-kube-apiserver-egress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Allow snapshot controller to talk to kube-apiserver.";
                endpointSelector.matchLabels.app = "snapshot-controller";
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
}
