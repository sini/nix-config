# Volume Snapshots — VolumeSnapshotClass CRDs for CSI snapshot support.
#
# Ported from main:modules/kubernetes/services/storage/volume-snapshots.nix
{ den, ... }:
{
  den.aspects.kubernetes.volume-snapshots = {
    k8s-manifests =
      { cluster, ... }:
      {
        applications.volume-snapshots = {
          namespace = "kube-system";

          resources = { };
        };
      };
  };
}
