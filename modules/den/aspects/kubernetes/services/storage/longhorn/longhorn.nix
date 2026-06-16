# Longhorn — distributed block storage via longhorn/longhorn Helm chart,
# 2-replica default, Retain policy, OIDC dashboard via Kanidm, HTTPRoute,
# CiliumNetworkPolicy.
{
  den.aspects.kubernetes.services.storage.longhorn = {
    service-domains = [ "longhorn" ];

    crds =
      { inputs, system, ... }:
      {
        name = "longhorn";
        chart = inputs.nixhelm.chartsDerivations.${system}.longhorn.longhorn;
        namePrefix = "longhorn";
      };

    age-secrets =
      { environment, ... }:
      {
        # Shares its rekeyFile AND generator with the kanidm OAuth2 client's
        # basicSecretFile, so both declarations resolve to the same value.
        age.secrets.longhorn-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/longhorn-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "longhorn";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        ...
      }:
      let
        # Off-cluster backup target declared on the cluster (type="backup").
        backupNfs = cluster.nfsVolumes."longhorn-backups";
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

          # Off-cluster backups: point the longhorn-created `default` BackupTarget
          # at the NAS NFS export. The chart's longhorn-default-resource ConfigMap
          # only SEEDS a non-existent target, so the existing `default` CR is
          # managed directly here — ArgoCD owns the spec, the longhorn controller
          # owns status (ignored below). NFS needs no credential secret.
          # The longhorn controller (`longhorn-manager` field manager) owns
          # /status and periodically rewrites /spec/syncRequestedAt (+ defaults
          # /spec/credentialSecret), flapping the app OutOfSync every poll. The
          # app uses serverSideDiff, where jsonPointers do NOT suppress this —
          # the SSA-native fix is managedFieldsManagers: ignore everything that
          # field manager owns. argocd-controller still owns (and git enforces)
          # backupTargetURL + pollInterval.
          ignoreDifferences."backup-target" = {
            group = "longhorn.io";
            kind = "BackupTarget";
            name = "default";
            namespace = "longhorn-system";
            managedFieldsManagers = [ "longhorn-manager" ];
          };

          # Longhorn's CRD installer stamps every longhorn.io CRD with
          # chart-version labels (app.kubernetes.io/version, helm.sh/chart,
          # app.kubernetes.io/managed-by) that the crds quirk extraction
          # deliberately strips. The values track the chart version, so they
          # can never match our generated manifests and flap every CRD
          # OutOfSync each poll. Cosmetic metadata owned by Longhorn — ignore
          # the label paths (jqPathExpressions, not managedFieldsManagers:
          # there is no single owning manager, ownership oscillates).
          ignoreDifferences."crd-chart-labels" = {
            group = "apiextensions.k8s.io";
            kind = "CustomResourceDefinition";
            jqPathExpressions = [
              ''.metadata.labels."app.kubernetes.io/version"''
              ''.metadata.labels."app.kubernetes.io/managed-by"''
              ''.metadata.labels."helm.sh/chart"''
            ];
          };

          objects = [
            {
              apiVersion = "longhorn.io/v1beta2";
              kind = "BackupTarget";
              metadata = {
                name = "default";
                namespace = "longhorn-system";
              };
              spec = {
                backupTargetURL = "nfs://${backupNfs.server}:${backupNfs.share}";
                pollInterval = "5m0s";
              };
            }
            # Local fast-rollback snapshots for the CNPG database volumes
            # (Longhorn-native, in-cluster — NOT a backup/upload). DB PVCs join
            # the `db-local-snap` group via inheritedMetadata labels on the CNPG
            # clusters. The authoritative off-cluster copy is the CNPG
            # type:bak ScheduledBackup; this is a cheap COW rollback point.
            {
              apiVersion = "longhorn.io/v1beta2";
              kind = "RecurringJob";
              metadata = {
                name = "db-local-snap";
                namespace = "longhorn-system";
              };
              spec = {
                task = "snapshot";
                cron = "0 */6 * * *";
                retain = 4;
                concurrency = 2;
                groups = [ "db-local-snap" ];
              };
            }
            # Nightly off-cluster backup of the app-config volumes (the media app
            # PVCs enrolled via the media-config group label on their config PVC).
            # loki/prometheus are intentionally unlabeled (observability TSDB is
            # treated as ephemeral), and never join via a default-group job.
            {
              apiVersion = "longhorn.io/v1beta2";
              kind = "RecurringJob";
              metadata = {
                name = "media-config-backup";
                namespace = "longhorn-system";
              };
              spec = {
                task = "backup";
                cron = "0 3 * * *";
                retain = 7;
                concurrency = 2;
                groups = [ "media-config" ];
              };
            }
          ];

          helm.releases.longhorn = {
            chart = charts.longhorn.longhorn;
            values = {
              longhorn.preUpgradeChecker.jobEnabled = false;

              # Longhorn-manager metrics ServiceMonitor (grafana.com dashboard
              # 13032 imported in monitoring/grafana.nix charts on these).
              metrics.serviceMonitor.enabled = true;

              preUpgradeChecker.upgradeVersionCheck = false;

              defaultSettings = {
                createDefaultDiskLabeledNodes = true;
                defaultDataPath = "/var/lib/longhorn";
                backupstorePollInterval = 300;
                replicaSoftAntiAffinity = true;
                replicaAutoBalance = "best-effort";
                # Cluster-wide default replica count. The longhorn StorageClass
                # already pins numberOfReplicas=2 (persistence.defaultClassReplicaCount
                # below), so every PVC is 2-replica regardless; this aligns the global
                # default (and the dashboard) so any volume created outside that class
                # also defaults to 2 rather than the chart default of 3.
                defaultReplicaCount = 2;
              };

              persistence = {
                defaultClass = true;
                defaultClassReplicaCount = 2;
                reclaimPolicy = "Retain";
              };

              longhornUI.replicas = 1;
            };
          };

          resources = {
            # Off-cluster (type:bak) snapshot class: CNPG ScheduledBackups using
            # it create Longhorn Backups uploaded to the NAS BackupTarget.
            # Coexists with the in-cluster `longhorn-snapshot` (type:snap) class
            # declared in media-pg.nix.
            volumeSnapshotClasses.longhorn-backup-nfs = {
              driver = "driver.longhorn.io";
              deletionPolicy = "Delete";
              parameters.type = "bak";
            };

            httpRoutes.longhorn-dashboard.spec = {
              hostnames = [ (cluster.domainFor "longhorn") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "longhorn"}-https";
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

            securityPolicies."longhorn-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "longhorn-dashboard";
                }
              ];

              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "longhorn";
                clientID = "longhorn";
                clientSecret.name = "longhorn-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.longhorn-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.longhorn-oidc-client-secret.sopsRef;
            };

            # Longhorn runs `longhorn system-backup`/backup mounts from the
            # pod netns, so reaching the NAS backupstore (an external/world IP)
            # needs an explicit egress allow — host-netns NFS (csi/kubelet)
            # bypasses pod policy, but this does not. NFSv4 = 2049/TCP; 111/TCP
            # (rpcbind) included for safety.
            ciliumNetworkPolicies.allow-nas-backup-egress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Allow Longhorn pods to reach the NAS NFS backupstore.";
                endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "longhorn-system";
                egress = [
                  {
                    toCIDR = [ "${backupNfs.server}/32" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "2049";
                            protocol = "TCP";
                          }
                          {
                            port = "111";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };

            ciliumNetworkPolicies.allow-kube-apiserver-egress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Allow Longhorn pods to talk to kube-apiserver.";
                endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "longhorn-system";
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
