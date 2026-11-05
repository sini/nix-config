# immich-pg — CloudNativePG PostgreSQL cluster backing immich.
#
# Its own cluster rather than a database on media-pg: immich needs the
# VectorChord extension, which the operator's default postgres image lacks, and
# a photo library's metadata (albums, faces, people) should not share a failure
# domain with the arr stack. Otherwise the hindsight-pg pattern — 2 instances on
# longhorn-single (CNPG owns redundancy via streaming replication), required
# anti-affinity, nightly volumeSnapshot backups to the NAS.
#
# The image is tensorchord's CNPG build with VectorChord (and the pgvector it
# depends on); immich accepts postgres >= 14 < 20 and VectorChord >= 0.3 < 2.0.
# vchord must be preloaded. The `immich` role owns the database but is not a
# superuser, so postInitApplicationSQL creates the extensions immich's
# migrations expect (upstream's "without superuser" setup). A VectorChord bump
# then needs `ALTER EXTENSION vchord UPDATE; REINDEX INDEX face_index;
# REINDEX INDEX clip_index;` by hand.
#
# References the cluster-scoped `longhorn-snapshot` VolumeSnapshotClass declared
# by media-pg.nix.
{
  den.aspects.kubernetes.services.media.immich-pg = {
    # Generated role password, rekeyed into the cluster sops store. The .age
    # file is created by `agenix generate` after this lands.
    age-secrets =
      { environment, ... }:
      {
        age.secrets.immich-pg-immich-password = {
          rekeyFile = environment.secretPath + "/immich-pg/immich-password.age";
          generator.script = "rfc3986-secret";
          sopsOutput = {
            file = "immich-pg";
            key = "immich";
          };
        };
      };

    k8s-manifests =
      { config, ... }:
      {
        applications.immich-pg = {
          namespace = "immich";

          # Manual metrics PodMonitor, replacing CNPG's deprecated
          # monitoring.enablePodMonitor. Relabels `instance` to the stable pod
          # name (immich-pg-1/2) instead of the ephemeral pod IP:port.
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "immich-pg-metrics";
                namespace = "immich";
              };
              spec = {
                selector.matchLabels = {
                  "cnpg.io/cluster" = "immich-pg";
                  "cnpg.io/podRole" = "instance";
                };
                podMetricsEndpoints = [
                  {
                    port = "metrics";
                    relabelings = [
                      {
                        sourceLabels = [ "__meta_kubernetes_pod_name" ];
                        targetLabel = "instance";
                      }
                    ];
                  }
                ];
              };
            }
          ];

          resources = {
            clusters.immich-pg.spec = {
              instances = 2;
              imageName = "ghcr.io/tensorchord/cloudnative-vectorchord:18-1.1.1@sha256:bff4fcc244543b856d59f70dc139a7c30ecedde6539400492bd0a3e8e9295a08";
              postgresql.shared_preload_libraries = [ "vchord.so" ];

              # Metrics scrape is via the manual PodMonitor above; CNPG's
              # deprecated monitoring.enablePodMonitor is intentionally not set.

              storage = {
                size = "10Gi";
                storageClass = "longhorn-single";
              };

              affinity.podAntiAffinityType = "required";

              bootstrap.initdb = {
                database = "immich";
                owner = "immich";
                secret.name = "immich-pg-immich-password";
                postInitApplicationSQL = [
                  "CREATE EXTENSION IF NOT EXISTS vchord CASCADE;"
                  "CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;"
                ];
              };

              # Authoritative backup → off-cluster NAS (type:bak). Local
              # fast-rollback is the db-local-snap Longhorn RecurringJob,
              # enrolled via inheritedMetadata.
              backup.volumeSnapshot.className = "longhorn-backup-nfs";

              inheritedMetadata.labels."recurring-job-group.longhorn.io/db-local-snap" = "enabled";
            };

            # Nightly backup at 05:00 — after the media-pg/coder-pg 04:00,
            # hindsight-pg 04:30 and paperless-pg 04:45 windows.
            scheduledBackups.immich-pg-nightly.spec = {
              schedule = "0 0 5 * * *";
              cluster.name = "immich-pg";
              method = "volumeSnapshot";
            };

            # basic-auth secret for the owner role. The nixidy objectTransform
            # rewrites Secret → SopsSecret; the password is a sops ref resolved
            # at render time.
            secrets = {
              immich-pg-immich-password = {
                type = "kubernetes.io/basic-auth";
                stringData = {
                  username = "immich";
                  password = config.age.secrets.immich-pg-immich-password.sopsRef;
                };
              };
            };

            ciliumNetworkPolicies = {
              # CNPG instance pods (instance manager) talk to the kube-apiserver.
              allow-immich-pg-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  description = "Allow immich-pg CNPG instance pods to talk to kube-apiserver.";
                  endpointSelector.matchLabels."cnpg.io/cluster" = "immich-pg";
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

              # Creating an ingress policy flips the instance pods to ingress
              # default-deny, so every legitimate caller is enumerated here:
              # immich (5432), peer replication (5432/8000), the cnpg-system
              # operator (8000), prometheus (9187 metrics).
              allow-immich-pg-internal.spec = {
                description = "immich-pg ingress: immich (5432), peer replication (5432/8000), CNPG operator (8000), prometheus (9187).";
                endpointSelector.matchLabels."cnpg.io/cluster" = "immich-pg";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "immich"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "5432";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    fromEndpoints = [
                      { matchLabels."cnpg.io/cluster" = "immich-pg"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "5432";
                            protocol = "TCP";
                          }
                          {
                            port = "8000";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "cnpg-system"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8000";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    fromEndpoints = [
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "monitoring";
                          "app.kubernetes.io/name" = "prometheus";
                        };
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "9187";
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
