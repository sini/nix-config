# Jellyfin in the cluster (docs/jellyfin-to-k8s.md), replacing uplink's
# declarative-jellyfin. One replica on the node whose iGPU it holds (owner,
# 2026-11-20: dedicate one node's GPU; llama-cpp's gpt-oss runs on the other two),
# with VA-API on radeonsi.
#
# Settings are applied by jellarr (github:sini/jellarr), a one-shot Job against the
# API. Its API key is a generated agenix secret that the `api-key` init container
# seeds into jellyfin.db before Jellyfin starts, since Jellyfin's API cannot take a
# chosen key value.
#
# Staged: a clean install at jellyfin-next.<domain> while uplink serves the real
# name. `live` moves jellyfin.<domain> here (after the data migration).
{ config, lib, ... }:
let
  # Jellyfin's SSO users who may stay: the people in media.access, the group the
  # kanidm `jellyfin` client is scoped to (services/security/kanidm.nix), through
  # nested groups. Kanidm's usernames are short names (preferShortUsername), and
  # SSO-Auth names Jellyfin users by preferred_username, so these are their names.
  mediaUsers =
    let
      groups = config.den.groups;
      nested =
        s:
        let
          n = lib.unique (s ++ lib.concatMap (g: groups.${g}.members or [ ]) s);
        in
        if lib.length n == lib.length s then s else nested n;
      access = nested [ "media.access" ];
    in
    lib.attrNames (
      lib.filterAttrs (_: u: lib.any (g: lib.elem g access) (u.groups or [ ])) config.den.users.registry
    );
  name = "jellyfin";
  namespace = "media";
  port = 8096;
  uid = 1027;
  # The node's render group, so the pod can open the iGPU's render node.
  renderGid = 303;
  pod."app.kubernetes.io/name" = name;
  ref = image: "${image.repository}@${image.digest}";
  secretsDir = "/run/secrets/jellyfin";
  # uplink's layout (services.jellyfin's defaults), so every absolute path in a migrated
  # database (the Shokofin VFS, metadata, plugins) stays valid without a rescan.
  dataDir = "/var/lib/jellyfin";
  cacheDir = "/var/cache/jellyfin";

  # Leaves exactly one ApiKeys row named "jellarr", carrying the agenix token.
  # Checks the 10.11 schema first, so a changed table fails the pod rather than
  # writing something Jellyfin won't read.
  seedApiKey = ''
    import os, sqlite3, sys, datetime
    db = "${dataDir}/data/jellyfin.db"
    if not os.path.exists(db):
        print("no jellyfin.db yet (first start); the key is seeded at the next pod start")
        sys.exit(0)
    token = open("${secretsDir}/api-key").read().strip()
    want = ["Id", "DateCreated", "DateLastActivity", "Name", "AccessToken"]
    con = sqlite3.connect(db)
    cols = [r[1] for r in con.execute("PRAGMA table_info(ApiKeys)")]
    if cols != want:
        sys.exit(f"ApiKeys schema is {cols}, expected {want}: not seeding")
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")
    with con:
        con.execute("DELETE FROM ApiKeys WHERE Name = 'jellarr' AND AccessToken != ?", (token,))
        if not con.execute("SELECT 1 FROM ApiKeys WHERE AccessToken = ?", (token,)).fetchone():
            con.execute(
                "INSERT INTO ApiKeys (DateCreated, DateLastActivity, Name, AccessToken) VALUES (?, ?, 'jellarr', ?)",
                (now, now, token),
            )
    print("api key seeded")
  '';

  # A consistent copy of each database (SQLite's online backup API, never cp) in
  # <dataDir>/db-backup, verified before it replaces the last one, so the Longhorn
  # backup after it carries a database that opens, not a mid-write snapshot.
  backupDatabases = ''
    import glob, os, sqlite3, sys
    out = "${dataDir}/db-backup"
    os.makedirs(out, exist_ok=True)
    dbs = sorted(glob.glob("${dataDir}/data/*.db"))
    if not dbs:
        print("no databases yet (first start)")
    for db in dbs:
        dst = os.path.join(out, os.path.basename(db))
        tmp = dst + ".partial"
        if os.path.exists(tmp):
            os.remove(tmp)
        src, copy = sqlite3.connect(db, timeout=60), sqlite3.connect(tmp)
        src.backup(copy)
        src.close()
        check = copy.execute("PRAGMA integrity_check").fetchone()[0]
        copy.close()
        if check != "ok":
            sys.exit(f"{db}: the copy fails integrity_check ({check}); kept the previous backup")
        os.replace(tmp, dst)
        print(f"{db} -> {dst}")
  '';
in
{
  den.aspects.kubernetes.services.media.jellyfin = {
    # Off while uplink's data is copied in (docs/jellyfin-to-k8s.md §4): replicas 0 and
    # no jellarr Job, so nothing writes the volume, or waits on a Jellyfin that isn't there.
    settings.serving = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the Jellyfin pod and its jellarr Job.";
    };

    settings.live = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Serve jellyfin.<domain> from the cluster (uplink stops serving it).";
    };

    served-domains =
      { cluster, ... }:
      cluster.servedDomains {
        services = [
          (if cluster.settings.kubernetes.services.media.jellyfin.live then "jellyfin" else "jellyfin-next")
        ];
        # Streams are long and large; Cloudflare's proxy would cap them.
        proxied = false;
      };

    age-secrets =
      { environment, config, ... }:
      {
        age.secrets = {
          jellyfin-api-key = {
            rekeyFile = environment.secretPath + "/jellyfin/api-key.age";
            generator.script =
              { pkgs, ... }:
              ''
                ${pkgs.openssl}/bin/openssl rand -hex 16 | tr -d '\n'
              '';
            sopsOutput = {
              file = "jellyfin";
              key = "api-key";
            };
          };
          jellyfin-admin-password = {
            rekeyFile = environment.secretPath + "/jellyfin/admin-password.age";
            generator.script = "rfc3986-secret";
            sopsOutput = {
              file = "jellyfin";
              key = "admin-password";
            };
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        images,
        ...
      }:
      let
        live = cluster.settings.kubernetes.services.media.jellyfin.live;
        serving = cluster.settings.kubernetes.services.media.jellyfin.serving;
        domain = cluster.domainFor (if live then "jellyfin" else "jellyfin-next");
        tcp = p: {
          port = toString p;
          protocol = "TCP";
        };
      in
      {
        applications.${name} = {
          inherit namespace;

          resources = {
            serviceAccounts.${name}.automountServiceAccountToken = false;

            secrets."${name}-secrets".stringData = {
              api-key = config.age.secrets.jellyfin-api-key.sopsRef;
              admin-password = config.age.secrets.jellyfin-admin-password.sopsRef;
            };

            configMaps."${name}-seed".data = {
              "seed-api-key.py" = seedApiKey;
              "backup-databases.py" = backupDatabases;
            };

            # jellarr's config: the shared setting (services/media/jellyfin.nix), called
            # with the cluster's values. JSON is valid YAML for --configFile.
            configMaps."${name}-jellarr".data."config.yml" = builtins.toJSON (
              cluster.settings.services.media.jellyfin.jellarr {
                baseUrl = "http://${name}.${namespace}.svc:${toString port}";
                inherit domain;
                adminPasswordFile = "/run/secrets/jellarr/admin-password";
                # The gateway's envoy pods, in the pod network.
                knownProxies = [ "172.20.0.0/16" ];
                # The Radeon 780M's VCN4 decoders (no MPEG-2, VC-1 or VP8).
                hardwareDecodingCodecs = [
                  "h264"
                  "hevc"
                  "vp9"
                  "av1"
                ];
              }
              // {
                # SSO-created users who left media.access are disabled (reversibly;
                # never deleted). Local accounts (Admin and the others) are out of scope.
                authoritative = {
                  users = "disable";
                  usersScope.authenticationProviderId = "Jellyfin.Plugin.SSO_Auth.Api.SSOController";
                  keep.users = mediaUsers;
                };
              }
            );

            # Applies the settings after every sync (and so after the pod's first start):
            # jellarr waits for Jellyfin, including a migration's 503s, up to 30 minutes.
            jobs = lib.optionalAttrs serving {
              "${name}-jellarr" = {
                metadata.annotations = {
                  "argocd.argoproj.io/hook" = "PostSync";
                  "argocd.argoproj.io/hook-delete-policy" = "BeforeHookCreation";
                };
                spec = {
                  backoffLimit = 3;
                  template = {
                    metadata.labels."app.kubernetes.io/name" = "${name}-jellarr";
                    spec = {
                      restartPolicy = "OnFailure";
                      automountServiceAccountToken = false;
                      enableServiceLinks = false;
                      securityContext = {
                        runAsNonRoot = true;
                        runAsUser = 65534;
                        runAsGroup = 65534;
                        fsGroup = 65534;
                        seccompProfile.type = "RuntimeDefault";
                      };
                      containers = [
                        {
                          name = "jellarr";
                          image = ref images."sini/jellarr";
                          args = [
                            "--configFile"
                            "/config/config.yml"
                          ];
                          env = [
                            {
                              name = "JELLARR_API_KEY_FILE";
                              value = "/run/secrets/jellarr/api-key";
                            }
                            {
                              name = "JELLARR_WAIT_TIMEOUT";
                              value = "1800";
                            }
                          ];
                          securityContext = {
                            allowPrivilegeEscalation = false;
                            readOnlyRootFilesystem = true;
                            capabilities.drop = [ "ALL" ];
                          };
                          volumeMounts = [
                            {
                              name = "config";
                              mountPath = "/config";
                              readOnly = true;
                            }
                            {
                              name = "secrets";
                              mountPath = "/run/secrets/jellarr";
                              readOnly = true;
                            }
                          ];
                        }
                      ];
                      volumes = [
                        {
                          name = "config";
                          configMap.name = "${name}-jellarr";
                        }
                        {
                          name = "secrets";
                          secret = {
                            secretName = "${name}-secrets";
                            defaultMode = 288;
                          };
                        }
                      ];
                    };
                  };
                };
              };
            };

            # Before the Longhorn media-config backup (03:00 UTC). On Jellyfin's node,
            # since the config volume is ReadWriteOnce.
            cronJobs."${name}-db-backup".spec = {
              schedule = "30 2 * * *";
              timeZone = "Etc/UTC";
              concurrencyPolicy = "Forbid";
              successfulJobsHistoryLimit = 1;
              failedJobsHistoryLimit = 3;
              jobTemplate.spec = {
                backoffLimit = 2;
                # A failed run holds KubeJobFailed for a week, then clears itself.
                ttlSecondsAfterFinished = 7 * 24 * 3600;
                template = {
                  metadata.labels."app.kubernetes.io/name" = "${name}-db-backup";
                  spec = {
                    restartPolicy = "OnFailure";
                    automountServiceAccountToken = false;
                    enableServiceLinks = false;
                    affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution = [
                      {
                        labelSelector.matchLabels = pod;
                        topologyKey = "kubernetes.io/hostname";
                      }
                    ];
                    securityContext = {
                      runAsUser = uid;
                      runAsGroup = uid;
                      runAsNonRoot = true;
                      seccompProfile.type = "RuntimeDefault";
                    };
                    containers = [
                      {
                        name = "backup";
                        image = ref images."library/python";
                        command = [
                          "python3"
                          "/seed/backup-databases.py"
                        ];
                        securityContext = {
                          allowPrivilegeEscalation = false;
                          readOnlyRootFilesystem = true;
                          capabilities.drop = [ "ALL" ];
                        };
                        volumeMounts = [
                          {
                            name = "config";
                            mountPath = dataDir;
                          }
                          {
                            name = "seed";
                            mountPath = "/seed";
                            readOnly = true;
                          }
                        ];
                      }
                    ];
                    volumes = [
                      {
                        name = "config";
                        persistentVolumeClaim.claimName = "${name}-data";
                      }
                      {
                        name = "seed";
                        configMap.name = "${name}-seed";
                      }
                    ];
                  };
                };
              };
            };

            # The data dir: the database, metadata, plugins and config. Sized from uplink's
            # (2026-11-21: 17 GB, 16 of it metadata, 0.8 the database; the 81 GB of
            # declarative-jellyfin backups not carried), with room to double; Longhorn
            # grows it online. In the nightly off-cluster backup group.
            persistentVolumeClaims = {
              "${name}-data" = {
                metadata.labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                spec = {
                  accessModes = [ "ReadWriteOnce" ];
                  storageClassName = "longhorn";
                  resources.requests.storage = "40Gi";
                };
              };
              # Transcodes and image cache: regenerable, single replica, not backed up.
              "${name}-cache".spec = {
                accessModes = [ "ReadWriteOnce" ];
                storageClassName = "longhorn-single";
                resources.requests.storage = "50Gi";
              };
            };

            deployments.${name}.spec = {
              replicas = if serving then 1 else 0;
              # One writer on SQLite and ReadWriteOnce volumes.
              strategy.type = "Recreate";
              selector.matchLabels = pod;
              template = {
                metadata.labels = pod;
                spec = {
                  serviceAccountName = name;
                  automountServiceAccountToken = false;
                  enableServiceLinks = false;
                  securityContext = {
                    runAsUser = uid;
                    runAsGroup = uid;
                    runAsNonRoot = true;
                    fsGroup = uid;
                    fsGroupChangePolicy = "OnRootMismatch";
                    supplementalGroups = [ renderGid ];
                    seccompProfile.type = "RuntimeDefault";
                  };
                  initContainers = [
                    {
                      name = "api-key";
                      image = ref images."library/python";
                      command = [
                        "python3"
                        "/seed/seed-api-key.py"
                      ];
                      securityContext = {
                        allowPrivilegeEscalation = false;
                        readOnlyRootFilesystem = true;
                        capabilities.drop = [ "ALL" ];
                      };
                      volumeMounts = [
                        {
                          name = "config";
                          mountPath = dataDir;
                        }
                        {
                          name = "seed";
                          mountPath = "/seed";
                          readOnly = true;
                        }
                        {
                          name = "secrets";
                          mountPath = secretsDir;
                          readOnly = true;
                        }
                      ];
                    }
                  ];
                  containers = [
                    {
                      inherit name;
                      image = ref images."jellyfin/jellyfin";
                      env = [
                        {
                          name = "JELLYFIN_PublishedServerUrl";
                          value = "https://${domain}";
                        }
                        # uplink's layout over the image's /config and /cache (its env).
                        {
                          name = "JELLYFIN_DATA_DIR";
                          value = dataDir;
                        }
                        {
                          name = "JELLYFIN_CONFIG_DIR";
                          value = "${dataDir}/config";
                        }
                        {
                          name = "JELLYFIN_LOG_DIR";
                          value = "${dataDir}/log";
                        }
                        {
                          name = "JELLYFIN_CACHE_DIR";
                          value = cacheDir;
                        }
                      ];
                      securityContext = {
                        allowPrivilegeEscalation = false;
                        capabilities.drop = [ "ALL" ];
                      };
                      ports = [
                        {
                          name = "http";
                          containerPort = port;
                        }
                      ];
                      # A major-version start migrates the database first (uplink's 10.11 → 12:
                      # ~10 minutes plus an optimise); up to 30 minutes before liveness counts.
                      startupProbe = {
                        httpGet = {
                          path = "/health";
                          port = "http";
                        };
                        periodSeconds = 15;
                        failureThreshold = 120;
                      };
                      readinessProbe = {
                        httpGet = {
                          path = "/health";
                          port = "http";
                        };
                        periodSeconds = 10;
                      };
                      livenessProbe = {
                        httpGet = {
                          path = "/health";
                          port = "http";
                        };
                        periodSeconds = 30;
                        failureThreshold = 6;
                      };
                      resources = {
                        requests = {
                          cpu = "500m";
                          memory = "1Gi";
                          "amd.com/gpu" = 1;
                        };
                        limits."amd.com/gpu" = 1;
                      };
                      volumeMounts = [
                        {
                          name = "config";
                          mountPath = dataDir;
                        }
                        {
                          name = "cache";
                          mountPath = cacheDir;
                        }
                        # The NAS at uplink's path, so library paths in a migrated
                        # database stay valid.
                        {
                          name = "media";
                          mountPath = "/mnt/data";
                          readOnly = true;
                        }
                      ];
                    }
                  ];
                  volumes = [
                    {
                      name = "config";
                      persistentVolumeClaim.claimName = "${name}-data";
                    }
                    {
                      name = "cache";
                      persistentVolumeClaim.claimName = "${name}-cache";
                    }
                    {
                      name = "media";
                      persistentVolumeClaim = {
                        claimName = "media-data-nfs";
                        readOnly = true;
                      };
                    }
                    {
                      name = "seed";
                      configMap.name = "${name}-seed";
                    }
                    {
                      name = "secrets";
                      secret = {
                        secretName = "${name}-secrets";
                        defaultMode = 288;
                      };
                    }
                  ];
                };
              };
            };

            services.${name}.spec = {
              selector = pod;
              ports = [
                {
                  name = "http";
                  inherit port;
                  targetPort = "http";
                }
              ];
            };

            httpRoutes.${name}.spec = {
              hostnames = [ domain ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.resourceForDomain domain}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      inherit name port;
                    }
                  ];
                }
              ];
            };

            # Long streams and the WebSocket.
            backendTrafficPolicies.${name}.spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  inherit name;
                }
              ];
              httpUpgrade = [ { type = "websocket"; } ];
              timeout.http = {
                requestTimeout = "0s";
                connectionIdleTimeout = "3600s";
              };
            };

            ciliumNetworkPolicies = {
              "allow-${name}-ingress".spec = {
                description = "jellyfin: the gateway on ${toString port}.";
                endpointSelector.matchLabels = pod;
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                      # jellarr's Job, against the API.
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = namespace;
                          "app.kubernetes.io/name" = "${name}-jellarr";
                        };
                      }
                      # seerr: library sync, availability and Jellyfin sign-in.
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = namespace;
                          "app.kubernetes.io/name" = "seerr";
                        };
                      }
                    ];
                    toPorts = [ { ports = [ (tcp port) ]; } ];
                  }
                ];
              };
              # Plugin repositories, the catalog, metadata providers and kanidm, all HTTPS.
              "allow-${name}-egress".spec = {
                description = "jellyfin: public HTTPS.";
                endpointSelector.matchLabels = pod;
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [ { ports = [ (tcp 443) ]; } ];
                  }
                ];
              };
            };
          };
        };
      };
  };
}
