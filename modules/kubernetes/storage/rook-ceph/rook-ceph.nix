# This module should work, but I'm not using it -- leaving for posterity
{
  flake.kubernetes.services.rook-ceph = {
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
        hosts =
          environment.findHostsByRole "kubernetes"
          |> lib.attrsets.filterAttrs (_hostname: hostConfig: hostConfig.tags ? "ceph-device");
        rookDomain = environment.getDomainFor "rook-dashboard";
        radosDomain = environment.getDomainFor "rook-rados";
      in
      {
        applications.rook-ceph = {
          namespace = "rook-ceph";

          syncPolicy = {
            syncOptions = {
              serverSideApply = true;
            };
          };

          compareOptions.serverSideDiff = true;

          helm.releases.rook-ceph = {
            chart = charts.rook-release.rook-ceph;
            values = {
              # https://github.com/rook/rook/blob/master/deploy/charts/rook-ceph/values.yaml
              crds.enabled = false; # Managed by bootstrap

              enableDiscoveryDaemon = true; # for "Physical Disks" in Ceph dashboard
              # useOperatorHostNetwork = true; # Host
              csi = {
                cephFSKernelMountOptions = "ms_mode=prefer-crc";
                enableCephfsDriver = true;
                # enableCSIHostNetwork = true; # Host
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
              toolbox = {
                enabled = true;
                # resources = {
                #   requests.cpu = "50m";
                #   requests.memory = "64Mi";
                # };
              };
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
                };
                cleanupPolicy.wipeDevicesFromOtherClusters = true;
                csi.readAffinity.enabled = true;
                dashboard = {
                  enabled = true;
                  port = 7000;
                  ssl = false;
                };
                mgr.modules =
                  let
                    enable = name: {
                      inherit name;
                      enabled = true;
                    };
                  in
                  [
                    (enable "insights")
                    (enable "pg_autoscaler")
                    (enable "rook")
                  ];
                # network.provider = "host";
                # network.ipFamily = "IPv4";
                # network.connections.requireMsgr2 = true;
                storage = {
                  useAllNodes = false;
                  useAllDevices = false;
                  allowDeviceClassUpdate = true;
                  allowOsdCrushWeightUpdate = true;
                  nodes =
                    builtins.attrValues hosts
                    |> map (hostConfig: {
                      name = hostConfig.hostname;
                      devices = [
                        {
                          fullpath = hostConfig.tags.ceph-device;
                        }
                      ];
                    });
                };
              };
              # cephFileSystems = [ ];
              cephBlockPoolsVolumeSnapshotClass.enabled = true;
            };
          };

          resources =
            let
              defaultPool = {
                failureDomain = "host";
                replicated.size = 2;
                deviceClass = "nvme";
              };
            in
            {
              cephBlockPools.rbd-nvme.spec = defaultPool;

              cephFilesystems.cephfs-nvme.spec = {
                metadataPool = defaultPool;
                dataPools = [
                  (
                    {
                      name = "nvme";
                    }
                    // defaultPool
                  )
                ];
                preserveFilesystemOnDelete = true;
                metadataServer = {
                  activeCount = 1;
                  activeStandby = true;
                };
              };

              cephObjectStores.rgw-nvme.spec = {
                metadataPool = defaultPool;
                dataPool = defaultPool;
                gateway = {
                  port = 80;
                  instances = 1;
                };
              };

              storageClasses =
                let
                  commonStorageClassParamters = {
                    clusterID = "rook-ceph";
                    "csi.storage.k8s.io/provisioner-secret-namespace" = "rook-ceph";
                    "csi.storage.k8s.io/controller-expand-secret-namespace" = "rook-ceph";
                    "csi.storage.k8s.io/node-stage-secret-namespace" = "rook-ceph";
                  };
                in
                rec {
                  rbd-nvme = {
                    provisioner = "rook-ceph.rbd.csi.ceph.com";
                    parameters = commonStorageClassParamters // {
                      pool = "rbd-nvme";
                      imageFormat = "2";
                      "csi.storage.k8s.io/provisioner-secret-name" = "rook-csi-rbd-provisioner";
                      "csi.storage.k8s.io/controller-expand-secret-name" = "rook-csi-rbd-provisioner";
                      "csi.storage.k8s.io/node-stage-secret-name" = "rook-csi-rbd-node";
                      "csi.storage.k8s.io/fstype" = "ext4";
                      # https://rook.io/docs/rook/latest-release/Getting-Started/Prerequisites/prerequisites/#rbd
                      imageFeatures = "layering,fast-diff,object-map,deep-flatten,exclusive-lock";
                    };
                    allowVolumeExpansion = true;
                    reclaimPolicy = "Delete";
                  };

                  rbd-nvme-retain = rbd-nvme // {
                    metadata.annotations."storageclass.kubernetes.io/is-default-class" = "true";
                    allowVolumeExpansion = true;
                    reclaimPolicy = "Retain";
                  };

                  cephfs-nvme = {
                    provisioner = "rook-ceph.cephfs.csi.ceph.com";
                    parameters = commonStorageClassParamters // {
                      fsName = "cephfs-nvme";
                      pool = "cephfs-nvme-nvme";
                      "csi.storage.k8s.io/provisioner-secret-name" = "rook-csi-cephfs-provisioner";
                      "csi.storage.k8s.io/controller-expand-secret-name" = "rook-csi-cephfs-provisioner";
                      "csi.storage.k8s.io/node-stage-secret-name" = "rook-csi-cephfs-node";
                    };
                    allowVolumeExpansion = true;
                    reclaimPolicy = "Delete";
                  };

                  cephfs-nvme-retain = cephfs-nvme // {
                    allowVolumeExpansion = true;
                    reclaimPolicy = "Retain";
                  };

                  rgw-nvme = {
                    provisioner = "rook-ceph.ceph.rook.io/bucket";
                    reclaimPolicy = "Delete";
                    parameters = {
                      objectStoreName = "rgw-nvme";
                      objectStoreNamespace = "rook-ceph";
                    };
                  };
                };

              volumeSnapshotClasses = {
                csi-rbdplugin-snapclass = {
                  driver = "rook-ceph.rbd.csi.ceph.com";
                  parameters = {
                    clusterID = "rook-ceph";
                    "csi.storage.k8s.io/snapshotter-secret-name" = "rook-csi-rbd-provisioner";
                    "csi.storage.k8s.io/snapshotter-secret-namespace" = "rook-ceph";
                  };
                  deletionPolicy = "Delete";
                };

                csi-cephfsplugin-snapclass = {
                  driver = "rook-ceph.cephfs.csi.ceph.com";
                  parameters = {
                    clusterID = "rook-ceph";
                    "csi.storage.k8s.io/snapshotter-secret-name" = "rook-csi-cephfs-provisioner";
                    "csi.storage.k8s.io/snapshotter-secret-namespace" = "rook-ceph";
                  };
                  deletionPolicy = "Delete";
                };
              };

              httpRoutes.rook-ceph-dashboard.spec = {
                hostnames = [ rookDomain ];
                parentRefs = [
                  {
                    name = "default-gateway";
                    namespace = "gateways";
                    sectionName = "${environment.domainToResourceName rookDomain}-https";
                  }
                ];
                rules = [
                  {
                    backendRefs = [
                      {
                        name = "rook-ceph-mgr-dashboard";
                        port = 7000;
                      }
                    ];
                  }
                ];
              };
              httpRoutes.rook-ceph-rados.spec = {
                hostnames = [ radosDomain ];
                parentRefs = [
                  {
                    name = "default-gateway";
                    namespace = "gateways";
                    sectionName = "${environment.domainToResourceName radosDomain}-https";
                  }
                ];
                rules = [
                  {
                    backendRefs = [
                      {
                        name = "rook-ceph-rgw-rgw-nvme";
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
                  endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "rook-ceph";
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
