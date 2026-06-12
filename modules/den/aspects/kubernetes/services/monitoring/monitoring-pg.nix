# monitoring-pg — CloudNativePG PostgreSQL cluster backing the monitoring
# stack (grafana today; alerting-era tenants later).
#
# Mirrors the media-pg pattern: 2-instance HA cluster on longhorn-single
# (CNPG owns redundancy via streaming replication), required anti-affinity,
# nightly volumeSnapshot backups. Deliberately separate from media-pg —
# the monitoring stack's state must not share a failure domain with a
# database cluster it monitors.
#
# References the cluster-scoped `longhorn-snapshot` VolumeSnapshotClass
# declared by media-pg.nix.
{ lib, ... }:
let
  roleApps = [ "grafana" ];

  passwordSecretName = app: "monitoring-pg-${app}-password";
in
{
  den.aspects.kubernetes.services.monitoring.monitoring-pg = {
    # One generated password per role, rekeyed into the cluster sops store.
    # The .age files are created by `agenix generate` after this lands.
    age-secrets =
      { environment, ... }:
      {
        age.secrets = lib.listToAttrs (
          map (
            app:
            lib.nameValuePair (passwordSecretName app) {
              rekeyFile = environment.secretPath + "/monitoring-pg/${app}-password.age";
              generator.script = "rfc3986-secret";
              sopsOutput = {
                file = "monitoring-pg";
                key = app;
              };
            }
          ) roleApps
        );
      };

    k8s-manifests =
      { config, ... }:
      {
        applications.monitoring-pg = {
          namespace = "monitoring";

          resources = {
            clusters.monitoring-pg.spec = {
              instances = 2;

              monitoring.enablePodMonitor = true;

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

              backup.volumeSnapshot.className = "longhorn-snapshot";
            };

            databases.grafana.spec = {
              cluster.name = "monitoring-pg";
              name = "grafana";
              owner = "grafana";
            };

            # Nightly backup at 04:00 via longhorn volume snapshot.
            scheduledBackups.monitoring-pg-nightly.spec = {
              schedule = "0 0 4 * * *";
              cluster.name = "monitoring-pg";
              method = "volumeSnapshot";
            };

            secrets = lib.listToAttrs (
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
            );

            ciliumNetworkPolicies = {
              # CNPG instance pods (instance manager) talk to the kube-apiserver.
              allow-monitoring-pg-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  description = "Allow monitoring-pg CNPG instance pods to talk to kube-apiserver.";
                  endpointSelector.matchLabels."cnpg.io/cluster" = "monitoring-pg";
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
              # grafana (5432), peer replication (5432/8000), the cnpg-system
              # operator (8000), prometheus (9187 metrics).
              allow-monitoring-pg-internal.spec = {
                description = "monitoring-pg ingress: grafana (5432), peer replication (5432/8000), CNPG operator (8000), prometheus (9187).";
                endpointSelector.matchLabels."cnpg.io/cluster" = "monitoring-pg";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "grafana"; }
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
                      { matchLabels."cnpg.io/cluster" = "monitoring-pg"; }
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
