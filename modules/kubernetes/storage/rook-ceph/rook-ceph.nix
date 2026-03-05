{ self, ... }:
let
  inherit (self.lib.kubernetes-utils) findKubernetesNodes;
in
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
        environment,
        lib,
        ...
      }:
      let
        hosts = findKubernetesNodes environment;
      in
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

          helm.releases.rook-ceph-cluster = {
            chart = charts.rook-release.rook-ceph-cluster;
            values = {
              operatorNamespace = "rook-ceph";
              # TODO: enable monitoring
              # monitoring.enabled = true;
              # monitoring.createPrometheusRules = true;
              # cephClusterSpec.dashboard.prometheusEndpoint =
              #   "http" + "://prometheus-operated.monitoring.svc.cluster.local:9090";
              cephClusterSpec = {
                cephConfig.global = {
                  bdev_enable_discard = "true";
                  bdev_async_discard_threads = "1";
                  osd_class_update_on_start = "false";
                  device_failure_prediction_mode = "local";
                };
                cleanupPolicy.wipeDevicesFromOtherClusters = true;
                csi.readAffinity.enabled = true;
                dashboard.enabled = true;
                dashboard.urlPrefix = "/";
                dashboard.ssl = false;
                mgr.modules =
                  let
                    enable = name: {
                      inherit name;
                      enabled = true;
                    };
                  in
                  [
                    (enable "diskprediction_local")
                    (enable "insights")
                    (enable "pg_autoscaler")
                    (enable "rook")
                  ];
                network.provider = "host";
                network.connections.requireMsgr2 = true;
                storage = {
                  useAllNodes = false;
                  useAllDevices = false;
                  allowDeviceClassUpdate = true;
                  allowOsdCrushWeightUpdate = true;
                  nodes =
                    builtins.attrValues hosts
                    |> lib.filter (hostConfig: hostConfig.tags ? ceph-device)
                    |> map (hostConfig: {
                      name = hostConfig.hostname;
                      devices = [ { name = hostConfig.tags.ceph-device; } ];
                    });
                };
              };
              cephFileSystems = [ ];
              cephBlockPoolsVolumeSnapshotClass.enabled = true;
            };
          };

          resources = {

            # Allow csi-driver-nfs access to kube-apiserver
            ciliumNetworkPolicies.allow-kube-apiserver-egress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Allow snapshot controller to talk to kube-apiserver.";
                endpointSelector.matchExpressions = [
                  {
                    key = "app";
                    operator = "In";
                    values = [
                      "rook-ceph-operator"
                      "rook-discover"
                      "rook-ceph-detect-version"
                    ];
                  }
                ];
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
