# media-pg — CloudNativePG PostgreSQL cluster backing the media stack.
#
# A single 2-instance HA postgres cluster in the `media` namespace serves every
# postgres-capable app (the *arrs, bazarr, romm). Each app gets:
#   - a login role (managed.roles), password sourced from an agenix-generated
#     secret rekeyed into a k8s basic-auth Secret (→ SopsSecret);
#   - one or two databases owned by that role (the *arrs split main/log per
#     Servarr convention; bazarr and romm use a single db each).
#
# Storage is longhorn-single (one longhorn replica per PV): CNPG owns redundancy
# via streaming replication between the two instances, so PV-level replication
# would be redundant. Required pod anti-affinity keeps the two instances on
# separate nodes. Nightly volumeSnapshot backups via ScheduledBackup, using the
# longhorn VolumeSnapshotClass declared here.
#
# Apps connect via the CNPG-managed services: media-pg-rw (primary, read-write)
# and media-pg-ro (replicas, read-only). Wired into app env in a later task.
{ lib, ... }:
let
  # Apps that get a login role + password secret.
  roleApps = [
    "sonarr"
    "radarr"
    "lidarr"
    "whisparr"
    "prowlarr"
    "bazarr"
    "romm"
  ];

  # *arrs split their data into a main db and a logs db (Servarr's
  # PostgresMainDb / PostgresLogDb). bazarr and romm use a single db.
  arrApps = [
    "sonarr"
    "radarr"
    "lidarr"
    "whisparr"
    "prowlarr"
  ];

  # Database CRs: { crName -> { db, owner } }. arrs → <app>-main/<app>-log,
  # single-db apps → <app>.
  arrDatabases = lib.listToAttrs (
    lib.concatMap (app: [
      (lib.nameValuePair "${app}-main" {
        db = "${app}-main";
        owner = app;
      })
      (lib.nameValuePair "${app}-log" {
        db = "${app}-log";
        owner = app;
      })
    ]) arrApps
  );

  singleDatabases = {
    bazarr = {
      db = "bazarr";
      owner = "bazarr";
    };
    romm = {
      db = "romm";
      owner = "romm";
    };
  };

  databases = arrDatabases // singleDatabases;

  passwordSecretName = app: "media-pg-${app}-password";

  # VolumeSnapshotClass for longhorn snapshots, referenced by both the cluster's
  # backup config and the nightly ScheduledBackup.
  snapshotClassName = "longhorn-snapshot";
in
{
  den.aspects.kubernetes.services.media.media-pg = {
    # One generated password per role, rekeyed into the cluster sops store.
    # The .age files are created by `agenix generate` after this lands.
    age-secrets =
      { environment, ... }:
      {
        age.secrets = lib.listToAttrs (
          map (
            app:
            lib.nameValuePair (passwordSecretName app) {
              rekeyFile = environment.secretPath + "/media-pg/${app}-password.age";
              generator.script = "rfc3986-secret";
              sopsOutput = {
                file = "media-pg";
                key = app;
              };
            }
          ) roleApps
        );
      };

    k8s-manifests =
      # `config` here is the nixidy module config: the cluster-age aspect imports
      # the agenix-rekey-to-sops bridge into these modules, so config.age.secrets
      # (and .sopsRef) are available, exactly as longhorn.nix uses them.
      { config, ... }:
      {
        applications.media-pg = {
          namespace = "media";

          resources = {
            # CNPG Cluster: 2 instances, single-replica longhorn storage,
            # required anti-affinity, per-app managed roles, nightly snapshots.
            clusters.media-pg.spec = {
              instances = 2;

              # PodMonitor for the instance metrics exporter (9187); scraped
              # by kube-prometheus-stack, charted by the CNPG cluster
              # dashboard (see monitoring/grafana.nix). The matching scrape
              # ingress allow lives in network-policy.nix.
              monitoring.enablePodMonitor = true;

              storage = {
                size = "20Gi";
                storageClass = "longhorn-single";
              };

              affinity.podAntiAffinityType = "required";

              managed.roles = map (app: {
                name = app;
                login = true;
                passwordSecret.name = passwordSecretName app;
              }) roleApps;

              # Authoritative backup → off-cluster NAS (type:bak). The in-cluster
              # longhorn-snapshot VSC stays declared below for manual CSI
              # snapshots; local fast-rollback is the db-local-snap Longhorn
              # RecurringJob, enrolled via inheritedMetadata.
              backup.volumeSnapshot.className = "longhorn-backup-nfs";

              # Enroll this cluster's PVCs into the db-local-snap RecurringJob
              # group (Longhorn-native local snapshots every 6h, retain 4).
              inheritedMetadata.labels."recurring-job-group.longhorn.io/db-local-snap" = "enabled";
            };

            # One Database CR per (db, owner). arrs split main/log; bazarr/romm
            # single. Owners are the managed roles above.
            databases = lib.mapAttrs (_crName: d: {
              spec = {
                cluster.name = "media-pg";
                name = d.db;
                owner = d.owner;
              };
            }) databases;

            # Nightly backup at 04:00 via longhorn volume snapshot.
            scheduledBackups.media-pg-nightly.spec = {
              schedule = "0 0 4 * * *";
              cluster.name = "media-pg";
              method = "volumeSnapshot";
            };

            # Longhorn VolumeSnapshotClass for CNPG volumeSnapshot backups.
            # `type: snap` takes an in-cluster longhorn snapshot (no external
            # backupstore required).
            volumeSnapshotClasses.${snapshotClassName} = {
              driver = "driver.longhorn.io";
              deletionPolicy = "Delete";
              parameters.type = "snap";
            };

            # Per-role password Secrets (basic-auth, username+password). The
            # nixidy objectTransform rewrites Secret → SopsSecret; the password
            # is a sops ref resolved at render time.
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

            # CNPG instance pods (instance manager) talk to the kube-apiserver.
            ciliumNetworkPolicies.allow-media-pg-apiserver-egress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Allow media-pg CNPG instance pods to talk to kube-apiserver.";
                endpointSelector.matchLabels."cnpg.io/cluster" = "media-pg";
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
