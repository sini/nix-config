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
{ lib, ... }:
let
  name = "jellyfin";
  namespace = "media";
  port = 8096;
  uid = 1027;
  # The node's render group, so the pod can open the iGPU's render node.
  renderGid = 303;
  pod."app.kubernetes.io/name" = name;
  ref = image: "${image.repository}@${image.digest}";
  secretsDir = "/run/secrets/jellyfin";

  # Leaves exactly one ApiKeys row named "jellarr", carrying the agenix token.
  # Checks the 10.11 schema first, so a changed table fails the pod rather than
  # writing something Jellyfin won't read.
  seedApiKey = ''
    import os, sqlite3, sys, datetime
    db = "/config/data/jellyfin.db"
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
in
{
  den.aspects.kubernetes.services.media.jellyfin = {
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

            configMaps."${name}-seed".data."seed-api-key.py" = seedApiKey;

            # config + data (the database, metadata, plugins). In the nightly
            # off-cluster backup group.
            persistentVolumeClaims = {
              "${name}-config" = {
                metadata.labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                spec = {
                  accessModes = [ "ReadWriteOnce" ];
                  storageClassName = "longhorn";
                  resources.requests.storage = "150Gi";
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
              replicas = 1;
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
                          mountPath = "/config";
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
                        initialDelaySeconds = 60;
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
                          mountPath = "/config";
                        }
                        {
                          name = "cache";
                          mountPath = "/cache";
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
                      persistentVolumeClaim.claimName = "${name}-config";
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
                    fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
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
