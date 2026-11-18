# atticd in the cluster: the fleet's binary cache at attic.<domain> (uplink plan
# Tier 1 item 4, owner 2026-11-18). Stateless pods on CNPG Postgres (attic-pg) and a
# Garage S3 bucket, replacing uplink's SQLite and local chunks, whose one connection
# bottlenecked parallel CI pushes.
#
# The `ci` cache is re-seeded (empty; CI repopulates it), but it keeps uplink's
# signing keypair, so `ci:1i+3fr…` stays the key every host trusts
# (core/nix/nix.nix), and the server keeps uplink's RS256 token secret, so CI's push
# token keeps working. attic's CLI only generates keypairs, so a PostSync Job creates
# `ci` through the API with the stored one; it skips a cache that exists.
#
# `live` gates the cutover: off, everything runs but the public name stays uplink's.
{ lib, ... }:
let
  name = "attic";
  namespace = "attic";
  ciCache = "ci";
  port = 8080;
  configDir = "/etc/attic";
  pod."app.kubernetes.io/name" = name;
  pgCluster = "attic-pg";
  ref = image: "${image.repository}@${image.digest}";
  uid = 65532;
  hardened = {
    runAsUser = uid;
    runAsGroup = uid;
    runAsNonRoot = true;
    readOnlyRootFilesystem = true;
    allowPrivilegeEscalation = false;
    capabilities.drop = [ "ALL" ];
  };
  podSecurity = {
    runAsUser = uid;
    runAsGroup = uid;
    runAsNonRoot = true;
    seccompProfile.type = "RuntimeDefault";
  };
in
{
  den.aspects.kubernetes.services.dev.attic = {
    settings.live = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Serve attic.<domain> from the cluster (uplink's atticd stops serving it).";
    };

    served-domains =
      { cluster, ... }:
      lib.optional cluster.settings.kubernetes.services.dev.attic.live (
        cluster.servedDomains {
          services = [ "attic" ];
          # Cloudflare's proxy caps a request at 100 MB; CI uploads are larger.
          proxied = false;
        }
      );

    age-secrets =
      {
        environment,
        config,
        lib,
        ...
      }:
      {
        age.secrets = {
          attic-pg-attic-password = {
            rekeyFile = environment.secretPath + "/attic-pg/attic-password.age";
            generator.script = "rfc3986-secret";
            sopsOutput = {
              file = "attic";
              key = "pg-password";
            };
          };
          attic-pg-dsn = {
            rekeyFile = environment.secretPath + "/attic-pg/dsn.age";
            generator.script = "template-file";
            generator.dependencies = [ config.age.secrets.attic-pg-attic-password ];
            settings.template = "postgres://attic:%attic-pg-attic-password%@${pgCluster}-rw.${namespace}:5432/attic?sslmode=require";
            sopsOutput = {
              file = "attic";
              key = "dsn";
            };
          };
          # uplink's: the same RS256 secret (services/nix/attic.nix) and env file.
          attic-k8s-server-env = {
            rekeyFile = environment.secretPath + "/attic/server-token.age";
            sopsOutput = {
              file = "attic";
              key = "server-token";
            };
          };
          # The cache Job's token: create and configure `ci` only, minted with the
          # server's RS256 secret by atticadm (it needs no running server), as
          # services/nix/attic.nix mints CI's push token.
          attic-ci-admin-token = {
            rekeyFile = environment.secretPath + "/attic/ci-admin-token.age";
            generator = {
              tags = [ "attic" ];
              dependencies = [ config.age.secrets.attic-k8s-server-env ];
              script =
                {
                  decrypt,
                  deps,
                  pkgs,
                  ...
                }:
                ''
                  ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=$(${decrypt} ${lib.escapeShellArg (lib.head deps).file}) \
                    ${pkgs.attic-server}/bin/atticadm -f ${
                      (pkgs.formats.toml { }).generate "server.toml" {
                        # atticadm only signs; it needs a parseable config, not these.
                        database.url = "sqlite::memory:";
                        storage = {
                          type = "local";
                          path = "/nonexistent";
                        };
                        chunking = {
                          nar-size-threshold = 1;
                          min-size = 1;
                          avg-size = 2;
                          max-size = 4;
                        };
                      }
                    } make-token \
                    --sub attic-ci-cache --validity 5y --pull ${ciCache} --push ${ciCache} \
                    --create-cache ${ciCache} --configure-cache ${ciCache} --configure-cache-retention ${ciCache}
                '';
            };
            sopsOutput = {
              file = "attic";
              key = "ci-admin-token";
            };
          };
          # The `ci` cache's signing keypair, copied once from uplink's database.
          attic-ci-keypair = {
            rekeyFile = environment.secretPath + "/attic/ci-keypair.age";
            sopsOutput = {
              file = "attic";
              key = "ci-keypair";
            };
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        images,
        pkgs,
        ...
      }:
      let
        live = cluster.settings.kubernetes.services.dev.attic.live;
        domain = cluster.domainFor "attic";
        image = ref images."zhaofengli/attic";
        busybox = ref images."library/busybox";
        # The database URL and S3 credentials come from the environment.
        settings = {
          listen = "[::]:${toString port}";
          allowed-hosts = [ domain ];
          api-endpoint = "https://${domain}/";
          # Required as a table; its url comes from ATTIC_SERVER_DATABASE_URL.
          database = { };
          storage = {
            type = "s3";
            region = "garage";
            bucket = name;
            endpoint = "http://garage.garage.svc:3900";
          };
          compression.type = "zstd";
          # As uplink's: coarse chunks, fewer dedup lookups per NAR.
          chunking = {
            nar-size-threshold = 1024 * 1024;
            min-size = 256 * 1024;
            avg-size = 1024 * 1024;
            max-size = 4 * 1024 * 1024;
          };
          garbage-collection = {
            interval = "12 hours";
            default-retention-period = "90 days";
          };
        };
        tokenEnv = {
          name = "ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64";
          valueFrom.secretKeyRef = {
            name = "${name}-secrets";
            key = "server-token";
          };
        };
        serverEnv = [
          tokenEnv
          {
            name = "ATTIC_SERVER_DATABASE_URL";
            valueFrom.secretKeyRef = {
              name = "${name}-secrets";
              key = "dsn";
            };
          }
          {
            name = "AWS_ACCESS_KEY_ID";
            valueFrom.secretKeyRef = {
              name = "${name}-s3";
              key = "access-key-id";
            };
          }
          {
            name = "AWS_SECRET_ACCESS_KEY";
            valueFrom.secretKeyRef = {
              name = "${name}-s3";
              key = "secret-access-key";
            };
          }
        ];
        configMount = {
          name = "config";
          mountPath = configDir;
          readOnly = true;
        };
        configVolume = {
          name = "config";
          configMap.name = "${name}-config";
        };
        tcp = p: {
          port = toString p;
          protocol = "TCP";
        };
      in
      {
        applications.${name} = {
          inherit namespace;
          createNamespace = true;

          objects = [
            {
              apiVersion = "garage.rajsingh.info/v1beta1";
              kind = "GarageBucket";
              metadata = {
                inherit name namespace;
              };
              spec = {
                clusterRef = {
                  name = "garage";
                  namespace = "garage";
                };
                globalAlias = name;
              };
            }
            {
              apiVersion = "garage.rajsingh.info/v1beta1";
              kind = "GarageKey";
              metadata = {
                name = "${name}-server";
                inherit namespace;
              };
              spec = {
                clusterRef = {
                  name = "garage";
                  namespace = "garage";
                };
                neverExpires = true;
                bucketPermissions = [
                  {
                    bucketRef.name = name;
                    read = true;
                    write = true;
                  }
                ];
                secretTemplate.name = "${name}-s3";
              };
            }
            # CNPG's metrics, as coder-pg.
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "${pgCluster}-metrics";
                inherit namespace;
              };
              spec = {
                selector.matchLabels = {
                  "cnpg.io/cluster" = pgCluster;
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
            serviceAccounts.${name}.automountServiceAccountToken = false;

            configMaps."${name}-config".data."server.toml" = builtins.readFile (
              (pkgs.formats.toml { }).generate "server.toml" settings
            );

            secrets = {
              "${name}-secrets".stringData = {
                server-token = config.age.secrets.attic-k8s-server-env.sopsRef;
                dsn = config.age.secrets.attic-pg-dsn.sopsRef;
                ci-keypair = config.age.secrets.attic-ci-keypair.sopsRef;
                ci-admin-token = config.age.secrets.attic-ci-admin-token.sopsRef;
              };
              "${pgCluster}-attic-password" = {
                type = "kubernetes.io/basic-auth";
                stringData = {
                  username = "attic";
                  password = config.age.secrets.attic-pg-attic-password.sopsRef;
                };
              };
            };

            clusters.${pgCluster}.spec = {
              instances = 2;
              storage = {
                size = "5Gi";
                storageClass = "longhorn-single";
              };
              affinity.podAntiAffinityType = "required";
              postgresql.synchronous = {
                method = "any";
                number = 1;
                dataDurability = "preferred";
              };
              managed.roles = [
                {
                  name = "attic";
                  login = true;
                  passwordSecret.name = "${pgCluster}-attic-password";
                }
              ];
              backup.volumeSnapshot.className = "longhorn-backup-nfs";
              inheritedMetadata.labels."recurring-job-group.longhorn.io/db-local-snap" = "enabled";
            };

            databases.attic.spec = {
              cluster.name = pgCluster;
              name = "attic";
              owner = "attic";
            };

            scheduledBackups."${pgCluster}-nightly".spec = {
              schedule = "0 30 4 * * *";
              cluster.name = pgCluster;
              method = "volumeSnapshot";
            };

            deployments.${name}.spec = {
              replicas = 1;
              selector.matchLabels = pod;
              template = {
                metadata.labels = pod;
                metadata.annotations."json64.dev/config-hash" = builtins.hashString "sha256" (
                  builtins.toJSON settings
                );
                spec = {
                  serviceAccountName = name;
                  automountServiceAccountToken = false;
                  enableServiceLinks = false;
                  securityContext = podSecurity;
                  containers = [
                    {
                      inherit name image;
                      args = [
                        "-f"
                        "${configDir}/server.toml"
                        "--mode"
                        "monolithic"
                      ];
                      env = serverEnv;
                      securityContext = hardened;
                      ports = [
                        {
                          name = "http";
                          containerPort = port;
                        }
                      ];
                      readinessProbe = {
                        tcpSocket.port = "http";
                        periodSeconds = 10;
                      };
                      volumeMounts = [
                        configMount
                        {
                          name = "tmp";
                          mountPath = "/tmp";
                        }
                      ];
                    }
                  ];
                  volumes = [
                    configVolume
                    {
                      name = "tmp";
                      emptyDir = { };
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

            # Creates `ci` with uplink's keypair when absent; a no-op otherwise, with
            # a token scoped to that one cache (attic-ci-admin-token).
            jobs."${name}-ci-cache" = {
              metadata.annotations = {
                "argocd.argoproj.io/hook" = "PostSync";
                "argocd.argoproj.io/hook-delete-policy" = "BeforeHookCreation";
              };
              spec = {
                backoffLimit = 6;
                template.spec = {
                  restartPolicy = "OnFailure";
                  automountServiceAccountToken = false;
                  # The Secret's files are root-owned; fsGroup makes them readable (0440).
                  securityContext = podSecurity // {
                    fsGroup = uid;
                  };
                  containers = [
                    {
                      name = "create";
                      image = busybox;
                      command = [
                        "/bin/sh"
                        "-c"
                        ''
                          set -eu
                          url="http://${name}.${namespace}.svc:${toString port}/_api/v1/cache-config/${ciCache}"
                          auth="Authorization: Bearer $(cat /secrets/ci-admin-token)"
                          host="Host: ${domain}"
                          if wget -q -O /dev/null --header "$auth" --header "$host" "$url"; then
                            echo "cache ${ciCache} exists: left unchanged"
                            exit 0
                          fi
                          kp=$(cat /secrets/ci-keypair)
                          body=$(printf '{"keypair":{"Keypair":"%s"},"is_public":true,"store_dir":"/nix/store","priority":41,"upstream_cache_key_names":["cache.nixos.org-1"]}' "$kp")
                          wget -q -O - --header "$auth" --header "$host" \
                            --header "Content-Type: application/json" --post-data "$body" "$url"
                          echo "cache ${ciCache} created with the stored keypair"
                        ''
                      ];
                      securityContext = hardened;
                      volumeMounts = [
                        {
                          name = "keypair";
                          mountPath = "/secrets";
                          readOnly = true;
                        }
                      ];
                    }
                  ];
                  volumes = [
                    {
                      name = "keypair";
                      secret = {
                        secretName = "${name}-secrets";
                        items = [
                          {
                            key = "ci-keypair";
                            path = "ci-keypair";
                          }
                          {
                            key = "ci-admin-token";
                            path = "ci-admin-token";
                          }
                        ];
                        defaultMode = 288;
                      };
                    }
                  ];
                };
              };
            };

            httpRoutes = lib.optionalAttrs live {
              ${name}.spec = {
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
            };

            # CI uploads: atticd chunks a whole NAR before it answers.
            backendTrafficPolicies = lib.optionalAttrs live {
              ${name}.spec = {
                targetRefs = [
                  {
                    group = "gateway.networking.k8s.io";
                    kind = "HTTPRoute";
                    inherit name;
                  }
                ];
                timeout.http = {
                  requestTimeout = "900s";
                  connectionIdleTimeout = "900s";
                };
              };
            };

            ciliumNetworkPolicies = {
              "allow-${name}-gateway-ingress".spec = {
                description = "attic: the gateway and the cache Job on ${toString port}.";
                endpointSelector.matchLabels = pod;
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = namespace; }
                    ];
                    toPorts = [ { ports = [ (tcp port) ]; } ];
                  }
                ];
              };
              "allow-${pgCluster}-apiserver-egress" = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  description = "Allow ${pgCluster} CNPG instance pods to talk to kube-apiserver.";
                  endpointSelector.matchLabels."cnpg.io/cluster" = pgCluster;
                  egress = [
                    {
                      toEntities = [ "kube-apiserver" ];
                      toPorts = [
                        {
                          ports = [
                            (tcp 443)
                            (tcp 6443)
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

        # Garage admits this namespace's bucket and key against its cluster.
        applications.garage.objects = [
          {
            apiVersion = "garage.rajsingh.info/v1beta1";
            kind = "GarageReferenceGrant";
            metadata = {
              name = "allow-${namespace}";
              namespace = "garage";
            };
            spec = {
              from = [
                {
                  kind = "GarageBucket";
                  inherit namespace;
                }
                {
                  kind = "GarageKey";
                  inherit namespace;
                }
              ];
              to = [
                {
                  kind = "GarageCluster";
                  name = "garage";
                }
              ];
            };
          }
        ];
      };
  };
}
