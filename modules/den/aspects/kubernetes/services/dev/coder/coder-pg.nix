# coder-pg — CloudNativePG PostgreSQL cluster backing the Coder control plane.
#
# Mirrors the monitoring-pg pattern: 2-instance HA cluster on longhorn-single
# (CNPG owns redundancy via streaming replication), required anti-affinity,
# nightly volumeSnapshot backups. coderd consumes a single composed connection
# URL (coder-pg-dsn, the chart's coder-db-url pattern); CNPG reads the role's
# basic-auth password from the same generated secret.
#
# References the cluster-scoped `longhorn-snapshot` VolumeSnapshotClass
# declared by media-pg.nix.
{ lib, ... }:
let
  roleApps = [ "coder" ];

  passwordSecretName = app: "coder-pg-${app}-password";
in
{
  den.aspects.kubernetes.services.dev.coder.coder-pg = {
    # One generated password per role, rekeyed into the cluster sops store.
    # The .age files are created by `agenix generate` after this lands.
    age-secrets =
      { environment, config, ... }:
      {
        age.secrets =
          lib.listToAttrs (
            map (
              app:
              lib.nameValuePair (passwordSecretName app) {
                rekeyFile = environment.secretPath + "/coder-pg/${app}-password.age";
                generator.script = "rfc3986-secret";
                sopsOutput = {
                  file = "coder-pg";
                  key = app;
                };
              }
            ) roleApps
          )
          // {
            # coderd wants one connection URL (the chart's coder-db-url pattern).
            # template-file substitutes the role password into a standalone DSN, so
            # the resulting sops value is a single ref that encrypts cleanly — unlike
            # a sopsRef embedded mid-string, which the live-encryption can't resolve.
            coder-pg-dsn = {
              rekeyFile = environment.secretPath + "/coder-pg/dsn.age";
              generator.script = "template-file";
              generator.dependencies = [ config.age.secrets.coder-pg-coder-password ];
              settings.template = "postgres://coder:%coder-pg-coder-password%@coder-pg-rw.coder:5432/coder?sslmode=require";
              sopsOutput = {
                file = "coder-pg";
                key = "dsn";
              };
            };
          };
      };

    k8s-manifests =
      { config, ... }:
      {
        applications.coder-pg = {
          namespace = "coder";

          # Manual metrics PodMonitor, replacing CNPG's deprecated
          # monitoring.enablePodMonitor. Relabels `instance` to the stable pod
          # name (coder-pg-1/2) instead of the ephemeral pod IP:port.
          # Replicates the CNPG auto spec; distinct name avoids a handoff race.
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "coder-pg-metrics";
                namespace = "coder";
              };
              spec = {
                selector.matchLabels = {
                  "cnpg.io/cluster" = "coder-pg";
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
            clusters.coder-pg.spec = {
              instances = 2;

              # Metrics scrape is via the manual PodMonitor above; CNPG's
              # deprecated monitoring.enablePodMonitor is intentionally not set.

              storage = {
                size = "5Gi";
                storageClass = "longhorn-single";
              };

              affinity.podAntiAffinityType = "required";

              managed.roles = map (app: {
                name = app;
                login = true;
                passwordSecret.name = passwordSecretName app;
              }) roleApps;

              # Authoritative backup → off-cluster NAS (type:bak). Local
              # fast-rollback is the db-local-snap Longhorn RecurringJob,
              # enrolled via inheritedMetadata.
              backup.volumeSnapshot.className = "longhorn-backup-nfs";

              inheritedMetadata.labels."recurring-job-group.longhorn.io/db-local-snap" = "enabled";
            };

            databases.coder.spec = {
              cluster.name = "coder-pg";
              name = "coder";
              owner = "coder";
            };

            # Nightly backup at 04:00 via longhorn volume snapshot.
            scheduledBackups.coder-pg-nightly.spec = {
              schedule = "0 0 4 * * *";
              cluster.name = "coder-pg";
              method = "volumeSnapshot";
            };

            # Basic-auth secret (username+password) per role for the CNPG managed
            # role. coderd consumes coder-pg-dsn (below) — a single connection URL
            # composed by the template-file generator, referenced as a standalone
            # sopsRef so it encrypts cleanly.
            secrets =
              lib.listToAttrs (
                map (
                  app:
                  lib.nameValuePair (passwordSecretName app) {
                    type = "kubernetes.io/basic-auth";
                    stringData = {
                      username = app;
                      password = config.age.secrets.${passwordSecretName app}.sopsRef;
                    };
                  }
                ) roleApps
              )
              // {
                coder-pg-dsn = {
                  type = "Opaque";
                  stringData.url = config.age.secrets.coder-pg-dsn.sopsRef;
                };
              };

            ciliumNetworkPolicies = {
              # CNPG instance pods (instance manager) talk to the kube-apiserver.
              allow-coder-pg-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  description = "Allow coder-pg CNPG instance pods to talk to kube-apiserver.";
                  endpointSelector.matchLabels."cnpg.io/cluster" = "coder-pg";
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
              # coderd (5432), peer replication (5432/8000), the cnpg-system
              # operator (8000), prometheus (9187 metrics).
              allow-coder-pg-internal.spec = {
                description = "coder-pg ingress: coderd (5432), peer replication (5432/8000), CNPG operator (8000), prometheus (9187).";
                endpointSelector.matchLabels."cnpg.io/cluster" = "coder-pg";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "coder"; }
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
                      { matchLabels."cnpg.io/cluster" = "coder-pg"; }
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
                      { matchLabels."app.kubernetes.io/name" = "prometheus"; }
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
