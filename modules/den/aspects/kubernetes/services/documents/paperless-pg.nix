# paperless-pg — CloudNativePG PostgreSQL cluster backing paperless-ngx.
#
# Its own cluster rather than a database on media-pg: scanned documents are
# irreplaceable personal records and should not share a failure domain with the
# media stack. Otherwise the hindsight-pg pattern — 2 instances on
# longhorn-single (CNPG owns redundancy via streaming replication), required
# anti-affinity, nightly volumeSnapshot backups to the NAS. paperless reads
# discrete PAPERLESS_DB* settings, so the owner's basic-auth Secret is all it
# needs (no composed DSN).
#
# References the cluster-scoped `longhorn-snapshot` VolumeSnapshotClass declared
# by media-pg.nix.
{
  den.aspects.kubernetes.services.documents.paperless-pg = {
    # Generated role password, rekeyed into the cluster sops store. The .age
    # file is created by `agenix generate` after this lands.
    age-secrets =
      { environment, ... }:
      {
        age.secrets.paperless-pg-paperless-password = {
          rekeyFile = environment.secretPath + "/paperless-pg/paperless-password.age";
          generator.script = "rfc3986-secret";
          sopsOutput = {
            file = "paperless-pg";
            key = "paperless";
          };
        };
      };

    k8s-manifests =
      { config, ... }:
      {
        applications.paperless-pg = {
          namespace = "paperless";

          # Manual metrics PodMonitor, replacing CNPG's deprecated
          # monitoring.enablePodMonitor. Relabels `instance` to the stable pod
          # name (paperless-pg-1/2) instead of the ephemeral pod IP:port.
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "paperless-pg-metrics";
                namespace = "paperless";
              };
              spec = {
                selector.matchLabels = {
                  "cnpg.io/cluster" = "paperless-pg";
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
            clusters.paperless-pg.spec = {
              instances = 2;

              # Metrics scrape is via the manual PodMonitor above; CNPG's
              # deprecated monitoring.enablePodMonitor is intentionally not set.

              storage = {
                size = "10Gi";
                storageClass = "longhorn-single";
              };

              affinity.podAntiAffinityType = "required";

              # Synchronous, durability preferred, as media-pg.nix: a failover loses no committed

              # write, and writes continue unreplicated while the standby is down.

              postgresql.synchronous = {

                method = "any";

                number = 1;

                dataDurability = "preferred";

              };

              bootstrap.initdb = {
                database = "paperless";
                owner = "paperless";
                secret.name = "paperless-pg-paperless-password";
              };

              # Authoritative backup → off-cluster NAS (type:bak). Local
              # fast-rollback is the db-local-snap Longhorn RecurringJob,
              # enrolled via inheritedMetadata.
              backup.volumeSnapshot.className = "longhorn-backup-nfs";

              inheritedMetadata.labels."recurring-job-group.longhorn.io/db-local-snap" = "enabled";
            };

            # Nightly backup at 04:45 — after the media-pg/coder-pg 04:00 and
            # hindsight-pg 04:30 windows, so the clusters don't snapshot longhorn at once.
            scheduledBackups.paperless-pg-nightly.spec = {
              schedule = "0 45 4 * * *";
              cluster.name = "paperless-pg";
              method = "volumeSnapshot";
            };

            # basic-auth secret for the owner role. The nixidy objectTransform
            # rewrites Secret → SopsSecret; the password is a sops ref resolved
            # at render time.
            secrets = {
              paperless-pg-paperless-password = {
                type = "kubernetes.io/basic-auth";
                stringData = {
                  username = "paperless";
                  password = config.age.secrets.paperless-pg-paperless-password.sopsRef;
                };
              };
            };

            ciliumNetworkPolicies = {
              # CNPG instance pods (instance manager) talk to the kube-apiserver.
              allow-paperless-pg-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  description = "Allow paperless-pg CNPG instance pods to talk to kube-apiserver.";
                  endpointSelector.matchLabels."cnpg.io/cluster" = "paperless-pg";
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
              # paperless (5432), peer replication (5432/8000), the cnpg-system
              # operator (8000), prometheus (9187 metrics).
              allow-paperless-pg-internal.spec = {
                description = "paperless-pg ingress: paperless (5432), peer replication (5432/8000), CNPG operator (8000), prometheus (9187).";
                endpointSelector.matchLabels."cnpg.io/cluster" = "paperless-pg";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "paperless"; }
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
                      { matchLabels."cnpg.io/cluster" = "paperless-pg"; }
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
