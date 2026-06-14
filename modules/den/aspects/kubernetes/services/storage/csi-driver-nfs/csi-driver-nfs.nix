# CSI Driver NFS — dynamic StorageClasses per NFS volume via
# kubernetes-csi/csi-driver-nfs Helm chart, proto=tcp nfsvers=4.1 noatime,
# CiliumNetworkPolicy.
{
  den.aspects.kubernetes.services.storage.csi-driver-nfs = {
    crds =
      { inputs, system, ... }:
      {
        name = "csi-driver-nfs";
        chart = inputs.nixhelm.chartsDerivations.${system}.kubernetes-csi.csi-driver-nfs;
      };

    k8s-manifests =
      {
        cluster,
        charts,
        lib,
        ...
      }:
      let
        inherit (cluster) nfsVolumes;
      in
      {
        applications.csi-driver-nfs = {
          namespace = "csi-nfs";

          helm.releases.csi-driver-nfs = {
            chart = charts.kubernetes-csi.csi-driver-nfs;
            # external-snapshotter: the cluster-wide snapshot-controller that
            # binds VolumeSnapshot -> VolumeSnapshotContent. Nothing else
            # deploys it (longhorn only ships the CSI sidecar), so without it
            # every volumeSnapshot Backup hangs in `started` with the
            # VolumeSnapshot unbound and event-less — bit the media-pg nightly.
            # The matching apiserver-egress CNP below predates this enable.
            values.externalSnapshotter = {
              enabled = true;
              # VolumeSnapshot CRDs already live on-cluster; a second emission
              # sync-blocks argo with RepeatedResourceWarning (the #99 trap).
              customResourceDefinitions.enabled = false;
            };
          };

          resources = {
            # Only type="storageclass" NFS targets become StorageClasses;
            # type="backup" (e.g. the Longhorn backupstore) is filtered out.
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
            }) (lib.filterAttrs (_: v: v.type == "storageclass") nfsVolumes);

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
