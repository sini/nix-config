# { lib, ... }:
{
  flake.kubernetes.services.rook-ceph = {

    # options = {
    #   volumes = lib.mkOption {
    #     type = lib.types.attrsOf (
    #       lib.types.submodule {
    #         options = {
    #           server = lib.mkOption {
    #             type = lib.types.str;
    #             description = "NFS server address";
    #           };
    #           share = lib.mkOption {
    #             type = lib.types.str;
    #             description = "NFS share path";
    #           };
    #         };
    #       }
    #     );
    #     default = { };
    #     description = "NFS volumes to create storage classes for";
    #   };
    # };

    crds =
      { inputs, system, ... }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.rook-release.rook-ceph;
      };

    nixidy =
      {
        charts,
        ...
      }:
      {
        applications.rook-ceph = {
          namespace = "rook-ceph";

          helm.releases.rook-ceph = {
            chart = charts.rook-release.rook-ceph;
            values = {
              # https://github.com/rook/rook/blob/master/deploy/charts/rook-ceph/values.yaml
              crds.enabled = false; # Managed by bootstrap

              enableDiscoveryDaemon = true; # for "Physical Disks" in Ceph dashboard
              csi = {
                cephFSKernelMountOptions = "ms_mode=prefer-crc";
                enableCephfsDriver = true;
              };

              # TODO: Enable monitoring
              #csi.serviceMonitor.enabled = true;
              #monitoring.enabled = true;

              # https://rook.io/docs/rook/latest-release/Getting-Started/Prerequisites/prerequisites/?h=nix#nixos
              csi.csiRBDPluginVolume = [
                {
                  name = "lib-modules";
                  hostPath.path = "/run/booted-system/kernel-modules/lib/modules/";
                }
                {
                  name = "host-nix";
                  hostPath.path = "/nix";
                }
              ];

              csi.csiRBDPluginVolumeMount = [
                {
                  name = "host-nix";
                  mountPath = "/nix";
                  readOnly = true;
                }
              ];

              csi.csiCephFSPluginVolume = [
                {
                  name = "lib-modules";
                  hostPath.path = "/run/booted-system/kernel-modules/lib/modules/";
                }
                {
                  name = "host-nix";
                  hostPath.path = "/nix";
                }
              ];

              csi.csiCephFSPluginVolumeMount = [
                {
                  name = "host-nix";
                  mountPath = "/nix";
                  readOnly = true;
                }
              ];
            };
          };

          # resources = {
          #   storageClasses = lib.mapAttrs (_volumeName: volumeConfig: {
          #     provisioner = "nfs.csi.k8s.io";
          #     reclaimPolicy = "Retain"; # or "Delete"
          #     volumeBindingMode = "Immediate";
          #     allowVolumeExpansion = true;

          #     parameters = {
          #       server = volumeConfig.server;
          #       share = volumeConfig.share;
          #       subDir = "\${pvc.metadata.namespace}/\${pvc.metadata.name}/\${pv.metadata.name}";
          #       # onDelete = "delete"; # delete|retain|archive
          #       # mountPermissions = "0";
          #     };

          #     mountOptions = [
          #       "proto=tcp"
          #       "noresvport"
          #       "nfsvers=4.1"
          #       "noauto"
          #       "noatime"
          #     ];
          #   }) config.kubernetes.services.csi-driver-nfs.volumes;

          #   # Allow csi-driver-nfs access to kube-apiserver
          #   ciliumNetworkPolicies.allow-kube-apiserver-egress = {
          #     metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
          #     spec = {
          #       description = "Allow snapshot controller to talk to kube-apiserver.";
          #       endpointSelector.matchLabels.app = "snapshot-controller";
          #       egress = [
          #         {
          #           toEntities = [ "kube-apiserver" ];
          #           toPorts = [
          #             {
          #               ports = [
          #                 {
          #                   port = "6443";
          #                   protocol = "TCP";
          #                 }
          #               ];
          #             }
          #           ];
          #         }
          #       ];
          #     };
          #   };
          # };
        };
      };
  };
}
