# The fleet's container registry (docker distribution) in the cluster at
# registry.<domain> (uplink plan Tier 1 item 5, owner 2026-11-17). A stateless
# pod on a Garage S3 bucket, replacing uplink's registry on local disk.
#
# Pushes come from workstations (virtualization/containers.nix) and pulls from
# the k3s nodes (services/k3s/k3s.nix), both as `builder` with the shared
# registry-password; the pod checks it against the bcrypt hash derived from it.
# Blobs stream through the pod (no S3 redirect), so the bucket is never
# addressed by clients.
#
# `live` gates the cutover: off, the pod and bucket exist while uplink keeps the
# name; on, the cluster serves the name and publishes the registry record.
{ lib, ... }:
let
  name = "registry";
  namespace = "registry";
  port = 5000;
  pod."app.kubernetes.io/name" = name;
  ref = image: "${image.repository}@${image.digest}";
  uid = 65532;
in
{
  den.aspects.kubernetes.services.dev.registry = {
    # Its blobs are a Garage bucket.
    s3-clients = _: { inherit namespace; };

    settings.live = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Serve registry.<domain> from the cluster and publish it to the k3s nodes.";
    };

    served-domains =
      { cluster, ... }:
      lib.optional cluster.settings.kubernetes.services.dev.registry.live (
        cluster.servedDomains {
          services = [ "registry" ];
          # Cloudflare's proxy caps a request at 100 MB; image layers are larger.
          proxied = false;
        }
      );

    # The k3s nodes' registries.yaml login (the password stays in each node's own
    # copy of the shared registry-password secret).
    container-registries =
      { cluster, ... }:
      lib.optional cluster.settings.kubernetes.services.dev.registry.live {
        domain = cluster.domainFor "registry";
        username = "builder";
      };

    age-secrets =
      {
        environment,
        config,
        ...
      }:
      {
        age.secrets = {
          # The shared cleartext password, the same rekeyFile and generator as its
          # other recipients; here only as the hash's generator input.
          registry-password = {
            rekeyFile = environment.secretPath + "/registry/registry-password.age";
            generator.script = "rfc3986-secret";
          };
          registry-htpasswd = {
            rekeyFile = environment.secretPath + "/registry/registry-htpasswd.age";
            generator.dependencies = [ config.age.secrets.registry-password ];
            generator.script = "htpasswd";
            settings.username = "builder";
            sopsOutput = {
              file = "registry";
              key = "htpasswd";
            };
          };
          # Signs upload state, so an upload can continue on either replica.
          registry-http-secret = {
            rekeyFile = environment.secretPath + "/registry/http-secret.age";
            generator.script = "rfc3986-secret";
            sopsOutput = {
              file = "registry";
              key = "http-secret";
            };
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        images,
        lib,
        pkgs,
        ...
      }:
      let
        live = cluster.settings.kubernetes.services.dev.registry.live;
        domain = cluster.domainFor "registry";
        settings = {
          version = "0.1";
          log.level = "info";
          http = {
            addr = ":${toString port}";
            # Relative upload locations, with no `host`: an absolute one names a single
            # address, so clients that reach the pod another way (a port-forward)
            # would be sent elsewhere mid-upload.
            relativeurls = true;
            debug = {
              addr = ":5001";
              prometheus.enabled = true;
            };
          };
          auth.htpasswd = {
            realm = domain;
            path = "/auth/htpasswd";
          };
          storage = {
            # Credentials from the AWS_* environment.
            s3 = {
              region = "garage";
              regionendpoint = "http://garage.garage.svc:3900";
              bucket = name;
              forcepathstyle = true;
            };
            redirect.disable = true;
            delete.enabled = true;
          };
        };
        tcp = p: {
          port = toString p;
          protocol = "TCP";
        };
        s3Env = key: env: {
          name = env;
          valueFrom.secretKeyRef = {
            name = "${name}-s3";
            inherit key;
          };
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
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "ServiceMonitor";
              metadata = {
                inherit name namespace;
              };
              spec = {
                selector.matchLabels = pod;
                endpoints = [ { port = "debug"; } ];
              };
            }
          ];

          resources = {
            serviceAccounts.${name}.automountServiceAccountToken = false;

            configMaps."${name}-config".data."config.yml" = builtins.toJSON settings;

            secrets."${name}-auth".stringData = {
              htpasswd = config.age.secrets.registry-htpasswd.sopsRef;
              http-secret = config.age.secrets.registry-http-secret.sopsRef;
            };

            deployments.${name}.spec = {
              replicas = 2;
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
                  securityContext = {
                    runAsUser = uid;
                    runAsGroup = uid;
                    runAsNonRoot = true;
                    fsGroup = uid;
                    seccompProfile.type = "RuntimeDefault";
                  };
                  # One replica per node.
                  topologySpreadConstraints = [
                    {
                      maxSkew = 1;
                      topologyKey = "kubernetes.io/hostname";
                      whenUnsatisfiable = "ScheduleAnyway";
                      labelSelector.matchLabels = pod;
                    }
                  ];
                  containers = [
                    {
                      inherit name;
                      image = ref images."library/registry";
                      args = [ "/etc/distribution/config.yml" ];
                      env = [
                        (s3Env "access-key-id" "AWS_ACCESS_KEY_ID")
                        (s3Env "secret-access-key" "AWS_SECRET_ACCESS_KEY")
                        {
                          name = "REGISTRY_HTTP_SECRET";
                          valueFrom.secretKeyRef = {
                            name = "${name}-auth";
                            key = "http-secret";
                          };
                        }
                      ];
                      securityContext = {
                        runAsUser = uid;
                        runAsGroup = uid;
                        runAsNonRoot = true;
                        readOnlyRootFilesystem = true;
                        allowPrivilegeEscalation = false;
                        capabilities.drop = [ "ALL" ];
                      };
                      ports = [
                        {
                          name = "http";
                          containerPort = port;
                        }
                        {
                          name = "debug";
                          containerPort = 5001;
                        }
                      ];
                      readinessProbe = {
                        httpGet = {
                          path = "/debug/health";
                          port = "debug";
                        };
                        periodSeconds = 10;
                      };
                      livenessProbe = {
                        tcpSocket.port = "http";
                        initialDelaySeconds = 10;
                        periodSeconds = 30;
                      };
                      resources.requests = {
                        cpu = "50m";
                        memory = "64Mi";
                      };
                      volumeMounts = [
                        {
                          name = "config";
                          mountPath = "/etc/distribution";
                          readOnly = true;
                        }
                        {
                          name = "auth";
                          mountPath = "/auth";
                          readOnly = true;
                        }
                        # Upload scratch; layers themselves go to S3.
                        {
                          name = "tmp";
                          mountPath = "/tmp";
                        }
                      ];
                    }
                  ];
                  volumes = [
                    {
                      name = "config";
                      configMap.name = "${name}-config";
                    }
                    {
                      name = "auth";
                      secret = {
                        secretName = "${name}-auth";
                        items = [
                          {
                            key = "htpasswd";
                            path = "htpasswd";
                          }
                        ];
                        defaultMode = 288;
                      };
                    }
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
                {
                  name = "debug";
                  port = 5001;
                  targetPort = "debug";
                }
              ];
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

            # Large layer uploads and downloads stream for minutes.
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

            ciliumNetworkPolicies."allow-${name}-ingress".spec = {
              description = "registry: the gateway on ${toString port}, metrics from Prometheus on 5001.";
              endpointSelector.matchLabels = pod;
              ingress = [
                {
                  fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
                  toPorts = [ { ports = [ (tcp port) ]; } ];
                }
                {
                  fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "monitoring"; } ];
                  toPorts = [ { ports = [ (tcp 5001) ]; } ];
                }
              ];
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
