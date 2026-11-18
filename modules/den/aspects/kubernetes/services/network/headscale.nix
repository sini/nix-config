# headscale, the tailnet's control plane, in the cluster (docs/uplink-maintenance-plan.md
# Tier 0 item 2, owner 2026-11-18). One replica (one instance owns the netmap) on
# SQLite in a Longhorn volume, which Longhorn replicates across nodes; upstream
# discourages Postgres (config-example.yaml at v0.29.7). Settings are the host
# aspect's (services/networking/_headscale-settings.nix).
#
# Ingress: the control protocol (POST /ts2021) and the embedded DERP relay
# (GET /derp) are HTTP upgrades, served on the gateway's HTTPS listener with the
# upgrade types allowed. STUN is UDP 3478 on its own LoadBalancer address,
# port-forwarded from the WAN; Local traffic policy keeps the client's address, which
# STUN reports back.
#
# `live` gates the cutover: off, the volume, config and services exist with no
# replica and no claim on the name. The volume must first hold uplink's db.sqlite,
# noise_private.key and derp_server_private.key, so clients keep their identities.
{ lib, ... }:
let
  name = "headscale";
  namespace = "headscale";
  hs = import ../../../services/networking/_headscale-settings.nix { inherit lib; };
  uid = 65532;
  httpPort = 8080;
  metricsPort = 9090;
  stunPort = 3478;
  stateDir = "/var/lib/headscale";
  configDir = "/etc/headscale";
  secretsDir = "/run/secrets/headscale";
  runDir = "/var/run/headscale";
  pod."app.kubernetes.io/name" = name;
  ref = image: "${image.repository}@${image.digest}";
  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
in
{
  den.aspects.kubernetes.services.network.headscale = {
    settings.live = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the replica and serve the headscale name from the cluster. Set only once the volume holds uplink's state (see the file header).";
    };

    served-domains =
      { cluster, ... }:
      lib.optional cluster.settings.kubernetes.services.network.headscale.live (
        cluster.servedDomains {
          services = [ "headscale" ];
          # The control protocol and DERP need a direct path, not Cloudflare's proxy.
          proxied = false;
        }
      );

    # STUN from the WAN, to the replica's node only (Local).
    port-forwards =
      { cluster, ... }:
      lib.optional cluster.settings.kubernetes.services.network.headscale.live {
        inherit (cluster) environment;
        name = "${cluster.name}-headscale-stun";
        mode = "nat";
        protocol = "udp";
        wanPort = toString stunPort;
        forward = {
          ip = cluster.getAssignment "headscale-stun";
          port = toString stunPort;
        };
      };

    age-secrets =
      { environment, ... }:
      {
        age.secrets.headscale-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/headscale-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "headscale";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        environment,
        images,
        dns-resolvers,
        exit-nodes,
        ...
      }:
      let
        live = cluster.settings.kubernetes.services.network.headscale.live;
        domain = cluster.domainFor "headscale";
        settings =
          hs.settings {
            inherit environment dns-resolvers;
            regionCode = cluster.name;
            oidcSecretPath = "${secretsDir}/oidc-secret";
            policyPath = "${configDir}/policy.json";
          }
          // {
            listen_addr = "0.0.0.0:${toString httpPort}";
            metrics_listen_addr = "0.0.0.0:${toString metricsPort}";
            grpc_listen_addr = "127.0.0.1:50443";
            unix_socket = "${runDir}/headscale.sock";
            disable_check_updates = true;
            noise.private_key_path = "${stateDir}/noise_private.key";
            database = {
              type = "sqlite";
              sqlite = {
                path = "${stateDir}/db.sqlite";
                write_ahead_log = true;
              };
            };
          };
        # The host aspect's DERP fields plus the paths it gets from the NixOS module.
        config' = lib.recursiveUpdate settings {
          derp = {
            urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
            paths = [ ];
            auto_update_enabled = true;
            update_frequency = "24h";
            server = {
              private_key_path = "${stateDir}/derp_server_private.key";
            }
            # The WAN address in the DERP map, so clients dial it for STUN and DERP
            # instead of resolving the name: on the LAN that name is the gateway VIP,
            # which carries HTTPS but not STUN's UDP (the hairpin rules cover the LAN).
            // lib.optionalAttrs (environment.dns.publicIPv4 != null) { ipv4 = environment.dns.publicIPv4; };
          };
        };
        hardened = {
          runAsUser = uid;
          runAsGroup = uid;
          runAsNonRoot = true;
          readOnlyRootFilesystem = true;
          allowPrivilegeEscalation = false;
          capabilities.drop = [ "ALL" ];
        };
      in
      {
        applications.${name} = {
          inherit namespace;
          createNamespace = true;

          resources = {
            serviceAccounts.${name}.automountServiceAccountToken = false;

            configMaps."${name}-config".data = {
              "config.yaml" = builtins.toJSON config';
              "policy.json" = builtins.toJSON (hs.policy exit-nodes);
            };

            secrets."${name}-oidc".stringData.oidc-secret =
              config.age.secrets.headscale-oidc-client-secret.sopsRef;

            # db.sqlite and the two private keys. Joins Longhorn's nightly off-cluster
            # backup group.
            persistentVolumeClaims.${name} = {
              metadata.labels."recurring-job-group.longhorn.io/media-config" = "enabled";
              spec = {
                accessModes = [ "ReadWriteOnce" ];
                storageClassName = "longhorn";
                resources.requests.storage = "1Gi";
              };
            };

            deployments.${name}.spec = {
              replicas = if live then 1 else 0;
              # One SQLite writer on a ReadWriteOnce volume.
              strategy.type = "Recreate";
              selector.matchLabels = pod;
              template = {
                metadata.labels = pod;
                # A config change must restart it: headscale reads its config at start.
                metadata.annotations."json64.dev/config-hash" = builtins.hashString "sha256" (
                  builtins.toJSON config'
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
                    fsGroupChangePolicy = "OnRootMismatch";
                    seccompProfile.type = "RuntimeDefault";
                  };
                  containers = [
                    {
                      inherit name;
                      image = ref images."juanfont/headscale";
                      args = [
                        "serve"
                        "--config"
                        "${configDir}/config.yaml"
                      ];
                      securityContext = hardened;
                      ports = [
                        {
                          name = "http";
                          containerPort = httpPort;
                        }
                        {
                          name = "metrics";
                          containerPort = metricsPort;
                        }
                        {
                          name = "stun";
                          containerPort = stunPort;
                          protocol = "UDP";
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
                        initialDelaySeconds = 30;
                        periodSeconds = 30;
                        failureThreshold = 4;
                      };
                      volumeMounts = [
                        {
                          name = "data";
                          mountPath = stateDir;
                        }
                        {
                          name = "config";
                          mountPath = configDir;
                          readOnly = true;
                        }
                        {
                          name = "oidc";
                          mountPath = secretsDir;
                          readOnly = true;
                        }
                        {
                          name = "run";
                          mountPath = runDir;
                        }
                      ];
                    }
                  ];
                  volumes = [
                    {
                      name = "data";
                      persistentVolumeClaim.claimName = name;
                    }
                    {
                      name = "config";
                      configMap.name = "${name}-config";
                    }
                    {
                      name = "oidc";
                      # Read by the pod's group (fsGroup), never world.
                      secret = {
                        secretName = "${name}-oidc";
                        defaultMode = 288;
                      };
                    }
                    {
                      name = "run";
                      emptyDir.medium = "Memory";
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
                  port = httpPort;
                  targetPort = "http";
                }
                {
                  name = "metrics";
                  port = metricsPort;
                  targetPort = "metrics";
                }
              ];
            };

            services."${name}-stun" = {
              metadata.annotations."lbipam.cilium.io/ips" = cluster.getAssignment "headscale-stun";
              spec = {
                type = "LoadBalancer";
                externalTrafficPolicy = "Local";
                selector = pod;
                ports = [
                  {
                    name = "stun";
                    port = stunPort;
                    targetPort = "stun";
                    protocol = "UDP";
                  }
                ];
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
                        inherit name;
                        port = httpPort;
                      }
                    ];
                  }
                ];
              };
            };

            # The control protocol and DERP are long-lived HTTP upgrades.
            backendTrafficPolicies = lib.optionalAttrs live {
              ${name}.spec = {
                targetRefs = [
                  {
                    group = "gateway.networking.k8s.io";
                    kind = "HTTPRoute";
                    inherit name;
                  }
                ];
                httpUpgrade = map (type: { inherit type; }) [
                  "tailscale-control-protocol"
                  "DERP"
                  "websocket"
                ];
              };
            };

            ciliumNetworkPolicies = {
              "allow-${name}-ingress".spec = {
                description = "headscale: the gateway on ${toString httpPort}, STUN from anywhere, metrics from Prometheus.";
                endpointSelector.matchLabels = pod;
                ingress = [
                  {
                    fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
                    toPorts = [ { ports = [ (tcp httpPort) ]; } ];
                  }
                  {
                    fromEntities = [
                      "world"
                      "cluster"
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = toString stunPort;
                            protocol = "UDP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "monitoring"; } ];
                    toPorts = [ { ports = [ (tcp metricsPort) ]; } ];
                  }
                ];
              };
              # Tailscale's DERP map, and kanidm at the gateway VIP (in-cluster).
              "allow-${name}-egress".spec = {
                description = "headscale: public HTTPS (the DERP map).";
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
