# Media namespace foundations — three storage tiers exposed to the media stack.
#
# scratch (NVMe on the download-scratch node, discovered via the
# media-scratch-exports quirk) is dual-exposed:
#   - local PV  (media-scratch-local, RWO) — node-pinned via volume nodeAffinity;
#     downloaders co-schedule on the scratch node and get NVMe-speed local IO.
#   - NFS PV    (media-scratch-nfs, RWX)   — arr pods consume the same scratch
#     dataset over NFS from anywhere in the cluster.
# media (media-data-nfs, RWX) is the NAS bulk library, sourced from
# cluster.nfsVolumes.vault-nfs.
#
# All endpoints (scratch node hostname/IP, export path, NAS server/share) come
# from the quirk + cluster schema — nothing hardcoded here. PVs are pinned to
# their PVCs via claimRef and protected from accidental data deletion with
# ArgoCD Prune=false,Delete=false on both PV and PVC.
{ lib, ... }:
let
  protect."argocd.argoproj.io/sync-options" = "Prune=false,Delete=false";
in
{
  den.aspects.kubernetes.services.media.base = {
    k8s-manifests =
      {
        cluster,
        media-scratch-exports,
        ...
      }:
      let
        scratch = lib.head media-scratch-exports;
        nas = cluster.nfsVolumes.vault-nfs;
      in
      {
        applications.media-base = {
          namespace = "media";

          # Namespace + storage tiers before the app fleet (wave 0) lands in them.
          annotations."argocd.argoproj.io/sync-wave" = "-1";

          resources = {
            # local-only StorageClass for node-pinned scratch volume. No
            # provisioner: the PV is statically declared below.
            storageClasses.local-scratch = {
              provisioner = "kubernetes.io/no-provisioner";
              volumeBindingMode = "WaitForFirstConsumer";
            };

            persistentVolumes = {
              # NVMe scratch as a local PV, pinned to the scratch node.
              media-scratch-local = {
                metadata.annotations = protect;
                spec = {
                  capacity.storage = "800Gi";
                  accessModes = [ "ReadWriteOnce" ];
                  persistentVolumeReclaimPolicy = "Retain";
                  storageClassName = "local-scratch";
                  local.path = scratch.exportPath;
                  claimRef = {
                    namespace = "media";
                    name = "media-scratch-local";
                  };
                  nodeAffinity.required.nodeSelectorTerms = [
                    {
                      matchExpressions = [
                        {
                          key = "kubernetes.io/hostname";
                          operator = "In";
                          values = [ scratch.hostname ];
                        }
                      ];
                    }
                  ];
                };
              };

              # Same scratch dataset over NFS for cluster-wide RWX access.
              media-scratch-nfs = {
                metadata.annotations = protect;
                spec = {
                  capacity.storage = "800Gi";
                  accessModes = [ "ReadWriteMany" ];
                  persistentVolumeReclaimPolicy = "Retain";
                  storageClassName = "";
                  nfs = {
                    server = scratch.ip;
                    path = scratch.exportPath;
                  };
                  mountOptions = [
                    "nfsvers=4.1"
                    "noatime"
                    "soft"
                    "timeo=50"
                  ];
                  claimRef = {
                    namespace = "media";
                    name = "media-scratch-nfs";
                  };
                };
              };

              # NAS bulk library over NFS.
              media-data-nfs = {
                metadata.annotations = protect;
                spec = {
                  capacity.storage = "1Ti";
                  accessModes = [ "ReadWriteMany" ];
                  persistentVolumeReclaimPolicy = "Retain";
                  storageClassName = "";
                  nfs = {
                    server = nas.server;
                    path = nas.share;
                  };
                  mountOptions = [
                    "nfsvers=4.1"
                    "noatime"
                  ];
                  claimRef = {
                    namespace = "media";
                    name = "media-data-nfs";
                  };
                };
              };
            };

            # PVCs auto-namespace to "media" (nixidy defaults metadata.namespace
            # to the application namespace for namespaced kinds). Each pins its
            # PV by volumeName so it binds the statically-provisioned volume.
            persistentVolumeClaims = {
              media-scratch-local = {
                metadata.annotations = protect;
                spec = {
                  accessModes = [ "ReadWriteOnce" ];
                  storageClassName = "local-scratch";
                  volumeName = "media-scratch-local";
                  resources.requests.storage = "800Gi";
                };
              };

              media-scratch-nfs = {
                metadata.annotations = protect;
                spec = {
                  accessModes = [ "ReadWriteMany" ];
                  storageClassName = "";
                  volumeName = "media-scratch-nfs";
                  resources.requests.storage = "800Gi";
                };
              };

              media-data-nfs = {
                metadata.annotations = protect;
                spec = {
                  accessModes = [ "ReadWriteMany" ];
                  storageClassName = "";
                  volumeName = "media-data-nfs";
                  resources.requests.storage = "1Ti";
                };
              };
            };
          };
        };
      };
  };
}
