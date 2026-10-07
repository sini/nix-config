# matrix-pg — CloudNativePG PostgreSQL cluster backing the Synapse homeserver.
#
# Its own cluster (the hindsight-pg / coder-pg pattern): 2 instances on
# longhorn-single (CNPG owns redundancy via streaming replication), required
# anti-affinity, nightly volumeSnapshot backups to the NAS.
#
# Synapse refuses to start on a database whose collation is not C, so initdb
# creates it with encoding UTF8 and LC_COLLATE/LC_CTYPE C. The `synapse` role
# owns the database; Synapse needs no extensions.
#
# Synapse reads its database credentials from the composed secrets.yaml built in
# synapse.nix, so there is no DSN secret here.
#
# References the cluster-scoped `longhorn-snapshot` VolumeSnapshotClass declared
# by media-pg.nix.
{
  den.aspects.kubernetes.services.communication.matrix.matrix-pg = {
    # Generated role password, rekeyed into the cluster sops store, plus the
    # composed DSN. The .age files are created by `agenix generate` after this
    # lands. template-file substitutes the password into a standalone URL so the
    # resulting sops value is a single ref that encrypts cleanly — a sopsRef
    # embedded mid-string cannot be resolved by the live-encryption.
    age-secrets =
      { environment, ... }:
      {
        age.secrets = {
          matrix-pg-synapse-password = {
            rekeyFile = environment.secretPath + "/matrix-pg/synapse-password.age";
            generator.script = "rfc3986-secret";
            sopsOutput = {
              file = "matrix-pg";
              key = "synapse";
            };
          };

        };
      };

    k8s-manifests =
      { config, ... }:
      {
        applications.matrix-pg = {
          namespace = "matrix";

          # Manual metrics PodMonitor, replacing CNPG's deprecated
          # monitoring.enablePodMonitor. Relabels `instance` to the stable pod
          # name (matrix-pg-1/2) instead of the ephemeral pod IP:port.
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "matrix-pg-metrics";
                namespace = "matrix";
              };
              spec = {
                selector.matchLabels = {
                  "cnpg.io/cluster" = "matrix-pg";
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
            clusters.matrix-pg.spec = {
              instances = 2;

              # Metrics scrape is via the manual PodMonitor above; CNPG's
              # deprecated monitoring.enablePodMonitor is intentionally not set.

              storage = {
                size = "10Gi";
                storageClass = "longhorn-single";
              };

              affinity.podAntiAffinityType = "required";

              # The app database and its owner role, with the C collation Synapse
              # requires (it checks LC_COLLATE/LC_CTYPE at startup).
              bootstrap.initdb = {
                database = "synapse";
                owner = "synapse";
                secret.name = "matrix-pg-synapse-password";
                encoding = "UTF8";
                localeCollate = "C";
                localeCType = "C";
              };

              # Authoritative backup → off-cluster NAS (type:bak). Local
              # fast-rollback is the db-local-snap Longhorn RecurringJob,
              # enrolled via inheritedMetadata.
              backup.volumeSnapshot.className = "longhorn-backup-nfs";

              inheritedMetadata.labels."recurring-job-group.longhorn.io/db-local-snap" = "enabled";
            };

            # Nightly backup at 05:00 — offset from media-pg/coder-pg (04:00) and
            # hindsight-pg (04:30) so the clusters don't snapshot longhorn at once.
            scheduledBackups.matrix-pg-nightly.spec = {
              schedule = "0 0 5 * * *";
              cluster.name = "matrix-pg";
              method = "volumeSnapshot";
            };

            # basic-auth secret for the owner role. The nixidy objectTransform
            # rewrites Secret → SopsSecret; the password is a sops ref resolved
            # at render time.
            secrets = {
              matrix-pg-synapse-password = {
                type = "kubernetes.io/basic-auth";
                stringData = {
                  username = "synapse";
                  password = config.age.secrets.matrix-pg-synapse-password.sopsRef;
                };
              };

            };

            ciliumNetworkPolicies = {
              # CNPG instance pods (instance manager) talk to the kube-apiserver.
              allow-matrix-pg-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  description = "Allow matrix-pg CNPG instance pods to talk to kube-apiserver.";
                  endpointSelector.matchLabels."cnpg.io/cluster" = "matrix-pg";
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
              # synapse (5432), peer replication (5432/8000), the cnpg-system
              # operator (8000), prometheus (9187 metrics).
              allow-matrix-pg-internal.spec = {
                description = "matrix-pg ingress: synapse (5432), peer replication (5432/8000), CNPG operator (8000), prometheus (9187).";
                endpointSelector.matchLabels."cnpg.io/cluster" = "matrix-pg";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "synapse"; }
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
                      { matchLabels."cnpg.io/cluster" = "matrix-pg"; }
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
