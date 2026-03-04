{ lib, ... }:
{
  flake.kubernetes.services.csi-driver-nfs = {

    options = {
      volumes = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              server = lib.mkOption {
                type = lib.types.str;
                description = "NFS server address";
              };
              share = lib.mkOption {
                type = lib.types.str;
                description = "NFS share path";
              };
            };
          }
        );
        default = { };
        description = "NFS volumes to create storage classes for";
      };
    };

    crds =
      { inputs, system, ... }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.kubernetes-csi.csi-driver-nfs;
      };

    nixidy =
      {
        config,
        lib,
        charts,
        ...
      }:
      {
        applications.csi-driver-nfs = {
          namespace = "csi-nfs";

          helm.releases.csi-driver-nfs = {
            chart = charts.kubernetes-csi.csi-driver-nfs;
          };

          resources.storageClasses = lib.mapAttrs (volumeName: volumeConfig: {
            provisioner = "nfs.csi.k8s.io";
            reclaimPolicy = "Retain"; # or "Delete"
            volumeBindingMode = "Immediate";
            allowVolumeExpansion = true;

            parameters = {
              server = volumeConfig.server;
              share = volumeConfig.share;
              subDir = "\${pvc.metadata.namespace}/\${pvc.metadata.name}/\${pv.metadata.name}";
              # onDelete = "delete"; # delete|retain|archive
              # mountPermissions = "0";
            };

            mountOptions = [
              "proto=tcp"
              "noresvport"
              "nfsvers=4.1"
              "noauto"
              "noatime"
            ];
          }) config.kubernetes.services.csi-driver-nfs.volumes;

        };
      };
  };
}
