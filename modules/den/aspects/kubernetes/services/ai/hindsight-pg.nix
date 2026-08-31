# hindsight-pg — CloudNativePG PostgreSQL cluster backing the hindsight bank.
#
# Its own cluster rather than a database on media-pg: the memory corpus is the
# fleet's law of record and should not share a failure domain with the media
# stack. Otherwise the coder-pg pattern — 2 instances on longhorn-single (CNPG
# owns redundancy via streaming replication), required anti-affinity, nightly
# volumeSnapshot backups to the NAS. hindsight consumes a single composed
# connection URL (hindsight-pg-dsn), the same shape coderd uses.
#
# The two extensions are created by postInitApplicationSQL rather than left to
# hindsight's own migrations: the `hindsight` role is the database owner, not a
# superuser. pgvector ships in the CNPG `standard`/`system` postgres images
# (the operator default here is ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie);
# pg_trgm is contrib, used by hindsight's entity resolution.
#
# References the cluster-scoped `longhorn-snapshot` VolumeSnapshotClass declared
# by media-pg.nix.
{
  den.aspects.kubernetes.services.ai.hindsight-pg = {
    # Generated role password, rekeyed into the cluster sops store, plus the
    # composed DSN. The .age files are created by `agenix generate` after this
    # lands. template-file substitutes the password into a standalone URL so the
    # resulting sops value is a single ref that encrypts cleanly — a sopsRef
    # embedded mid-string cannot be resolved by the live-encryption.
    age-secrets =
      { environment, config, ... }:
      {
        age.secrets = {
          hindsight-pg-hindsight-password = {
            rekeyFile = environment.secretPath + "/hindsight-pg/hindsight-password.age";
            generator.script = "rfc3986-secret";
            sopsOutput = {
              file = "hindsight-pg";
              key = "hindsight";
            };
          };

          hindsight-pg-dsn = {
            rekeyFile = environment.secretPath + "/hindsight-pg/dsn.age";
            generator.script = "template-file";
            generator.dependencies = [ config.age.secrets.hindsight-pg-hindsight-password ];
            # Fully qualified on purpose. Measured from a pod in this namespace:
            # `hindsight-pg-rw.ai` gets NXDOMAIN, `hindsight-pg-rw.ai.svc.cluster.local`
            # returns the ClusterIP; hindsight's psycopg2 failed on the short form
            # with "could not translate host name" even with the primary Ready and
            # the -rw service carrying an endpoint.
            #
            # Why the short form fails here is NOT established. The obvious guess —
            # that `ai` collides with the real .ai TLD, so the Corefile's
            # `forward . 1.1.1.1` answers it authoritatively — does not survive its
            # control: `coder-pg-rw.coder` resolves exactly the same way (NXDOMAIN
            # queried absolutely) and coderd connects fine. So the FQDN is used
            # because it is the form measured to work, not because the mechanism is
            # understood. Don't shorten it back without re-measuring.
            settings.template = "postgresql://hindsight:%hindsight-pg-hindsight-password%@hindsight-pg-rw.ai.svc.cluster.local:5432/hindsight?sslmode=require";
            sopsOutput = {
              file = "hindsight-pg";
              key = "dsn";
            };
          };
        };
      };

    k8s-manifests =
      { config, ... }:
      {
        applications.hindsight-pg = {
          namespace = "ai";

          # Manual metrics PodMonitor, replacing CNPG's deprecated
          # monitoring.enablePodMonitor. Relabels `instance` to the stable pod
          # name (hindsight-pg-1/2) instead of the ephemeral pod IP:port.
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "hindsight-pg-metrics";
                namespace = "ai";
              };
              spec = {
                selector.matchLabels = {
                  "cnpg.io/cluster" = "hindsight-pg";
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
            clusters.hindsight-pg.spec = {
              instances = 2;

              # Metrics scrape is via the manual PodMonitor above; CNPG's
              # deprecated monitoring.enablePodMonitor is intentionally not set.

              storage = {
                size = "10Gi";
                storageClass = "longhorn-single";
              };

              affinity.podAntiAffinityType = "required";

              # The app database, its owner role, and the extensions hindsight's
              # migrations expect to already exist. postInitApplicationSQL runs
              # as superuser inside the freshly created database, which is the
              # only place CREATE EXTENSION can succeed here.
              bootstrap.initdb = {
                database = "hindsight";
                owner = "hindsight";
                secret.name = "hindsight-pg-hindsight-password";
                postInitApplicationSQL = [
                  "CREATE EXTENSION IF NOT EXISTS vector;"
                  "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
                ];
              };

              # Authoritative backup → off-cluster NAS (type:bak). Local
              # fast-rollback is the db-local-snap Longhorn RecurringJob,
              # enrolled via inheritedMetadata.
              backup.volumeSnapshot.className = "longhorn-backup-nfs";

              inheritedMetadata.labels."recurring-job-group.longhorn.io/db-local-snap" = "enabled";
            };

            # Nightly backup at 04:30 — offset from the media-pg/coder-pg 04:00
            # window so the three clusters don't snapshot longhorn at once.
            scheduledBackups.hindsight-pg-nightly.spec = {
              schedule = "0 30 4 * * *";
              cluster.name = "hindsight-pg";
              method = "volumeSnapshot";
            };

            # basic-auth secret for the owner role. The nixidy objectTransform
            # rewrites Secret → SopsSecret; the password is a sops ref resolved
            # at render time.
            secrets = {
              hindsight-pg-hindsight-password = {
                type = "kubernetes.io/basic-auth";
                stringData = {
                  username = "hindsight";
                  password = config.age.secrets.hindsight-pg-hindsight-password.sopsRef;
                };
              };

              hindsight-pg-dsn = {
                type = "Opaque";
                stringData.url = config.age.secrets.hindsight-pg-dsn.sopsRef;
              };
            };

            ciliumNetworkPolicies = {
              # CNPG instance pods (instance manager) talk to the kube-apiserver.
              allow-hindsight-pg-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  description = "Allow hindsight-pg CNPG instance pods to talk to kube-apiserver.";
                  endpointSelector.matchLabels."cnpg.io/cluster" = "hindsight-pg";
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
              # hindsight (5432), peer replication (5432/8000), the cnpg-system
              # operator (8000), prometheus (9187 metrics).
              allow-hindsight-pg-internal.spec = {
                description = "hindsight-pg ingress: hindsight (5432), peer replication (5432/8000), CNPG operator (8000), prometheus (9187).";
                endpointSelector.matchLabels."cnpg.io/cluster" = "hindsight-pg";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "hindsight"; }
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
                      { matchLabels."cnpg.io/cluster" = "hindsight-pg"; }
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
