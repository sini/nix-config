# CloudNativePG — PostgreSQL operator via cloudnative-pg/cloudnative-pg Helm
# chart. Owns the postgresql.cnpg.io CRDs (Cluster, Database, ScheduledBackup,
# …) and the operator deployment in cnpg-system. Postgres clusters themselves
# (e.g. media-pg) live in their own app aspects.
#
# Also declares the longhorn-single StorageClass: single-replica longhorn block
# storage for postgres data volumes. CNPG owns redundancy at the database layer
# (streaming replication across instances), so longhorn replicating each PV
# would be wasteful double-redundancy — one longhorn replica per CNPG instance.
{
  den.aspects.kubernetes.services.storage.cloudnative-pg = {
    # CRD scope has no `charts` arg — build from inputs/system like longhorn.
    # No kindFilter: register every CNPG CRD (Cluster/Database/ScheduledBackup/…).
    # No namePrefix: it prefixes the generated resource accessor names
    # (cloudnative-pgClusters …); media-pg.nix consumes resources.clusters /
    # .databases / .scheduledBackups directly, so keep the plain plural names.
    crds =
      { inputs, system, ... }:
      {
        name = "cloudnative-pg";
        chart = inputs.nixhelm.chartsDerivations.${system}.cloudnative-pg.cloudnative-pg;
      };

    k8s-manifests =
      { charts, ... }:
      {
        applications.cloudnative-pg = {
          namespace = "cnpg-system";

          # CNPG CRDs are huge; server-side apply avoids the
          # last-applied-configuration annotation size limit.
          syncPolicy.syncOptions.serverSideApply = true;
          compareOptions.serverSideDiff = true;

          helm.releases.cloudnative-pg = {
            chart = charts.cloudnative-pg.cloudnative-pg;
            values = {
              # CRDs are deployed via the bootstrap app (crds bridge), not the
              # operator chart, to keep them out of the helm release lifecycle.
              crds.create = false;
            };
          };

          resources = {
            # Single-replica longhorn class for postgres data volumes.
            storageClasses.longhorn-single = {
              provisioner = "driver.longhorn.io";
              reclaimPolicy = "Retain";
              allowVolumeExpansion = true;
              volumeBindingMode = "Immediate";
              parameters = {
                numberOfReplicas = "1";
                staleReplicaTimeout = "30";
              };
            };

            ciliumNetworkPolicies.allow-kube-apiserver-egress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Allow CloudNativePG operator to talk to kube-apiserver.";
                endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "cnpg-system";
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
