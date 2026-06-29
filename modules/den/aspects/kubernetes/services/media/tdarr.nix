# Tdarr — distributed media transcoding stack (server + node workers).
#
# Tdarr splits into a *server* (`applications.tdarr`) and a fleet of *node*
# workers (`applications.tdarr-node`, the DaemonSet sibling below). The server
# runs the UI, the library DB, and the job orchestrator; it does NOT transcode
# itself
# (`internalNode = false`). It scans the NAS library over NFS (read-only /data)
# and hands transcode jobs to the external nodes, which connect back on the
# server's node port (8266).
#
# Ports:
#   8265  webUI  — the React UI + REST, routed + OIDC-protected on tdarr.<domain>
#   8266  node   — node-worker control channel (tdarr-node pods dial in here)
# The Service publishes both; `http` is primary (a multi-port app-template
# Service needs exactly one `primary = true`).
#
# Storage:
#   config  longhorn RWO — the server DB + configs + logs live on three subdirs
#           of one PVC (/app/server, /app/configs, /app/logs).
#   data    media-data-nfs (RWX) mounted read-only at /data — the server only
#           SCANS the library; transcode IO happens on the nodes.
#
# Networking: gateway-ingress (8265) flips the pod to default-deny ingress, so
# the node-worker control channel (8266) needs its own explicit ingress CNP
# (allow-nodeconn-ingress-tdarr) or the nodes can't register. No NFS-egress CNP:
# NFS mounts in the host netns, outside pod policy (mirrors the arrs).
#
# Metrics: the homeylab/tdarr-exporter v3 sidecar scrapes the server over pod
# loopback and re-exports on :9090 for kube-prometheus-stack (PodMonitor below).
{
  den.aspects.kubernetes.services.media.tdarr = {
    service-domains = [ "tdarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.tdarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/tdarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "tdarr";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        images,
        ...
      }:
      {
        applications.tdarr = {
          namespace = "media";

          helm.releases.tdarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                # Single-writer DB on an RWO PVC: tear the old pod down before the
                # new one mounts /app/server.
                strategy = "Recreate";

                containers.main = {
                  image = {
                    inherit (images."haveagitgat/tdarr") repository digest;
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    inContainer = "true";
                    # Server orchestrates only — transcoding is the nodes' job.
                    internalNode = "false";
                    serverIP = "0.0.0.0";
                    serverPort = "8266";
                    webUIPort = "8265";
                  };
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/";
                      port = 8265;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/";
                      port = 8265;
                    };
                  };
                };

                # Prometheus metrics sidecar (homeylab/tdarr-exporter v3): scrapes
                # the tdarr server API over pod loopback and re-exports on :9090.
                containers.exportarr = {
                  image = {
                    inherit (images."homeylab/tdarr-exporter") repository digest;
                  };
                  env = {
                    TDARR_URL = "http://localhost:8265";
                    PROMETHEUS_PORT = "9090";
                    LOG_LEVEL = "warn";
                  };
                  ports = [
                    {
                      name = "metrics";
                      containerPort = 9090;
                    }
                  ];
                };
              };

              service.main = {
                controller = "main";
                ports.http = {
                  port = 8265;
                  primary = true;
                };
                ports.node = {
                  port = 8266;
                };
              };

              persistence = {
                # Server DB + configs + logs on one longhorn RWO PVC.
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "5Gi";
                  storageClass = "longhorn";
                  labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                  globalMounts = [
                    { path = "/app/server"; }
                    { path = "/app/configs"; }
                    { path = "/app/logs"; }
                  ];
                };
                # NAS library over NFS, read-only — the server only scans it.
                data = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [
                    {
                      path = "/data";
                      readOnly = true;
                    }
                  ];
                };
              };
            };
          };

          # Raw PodMonitor: no typed accessor without a kube-prometheus-stack
          # CRDs bridge, so author it directly (mirrors the monitoring aspect).
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "tdarr";
                namespace = "media";
              };
              spec = {
                selector.matchLabels."app.kubernetes.io/name" = "tdarr";
                podMetricsEndpoints = [
                  {
                    port = "metrics";
                    path = "/metrics";
                    interval = "30s";
                    # Default instance is the ephemeral pod IP:port, which
                    # churns on every restart; pin it to the stable app name.
                    relabelings = [
                      {
                        sourceLabels = [ "__meta_kubernetes_pod_label_app_kubernetes_io_name" ];
                        targetLabel = "instance";
                      }
                    ];
                  }
                ];
              };
            }
          ];

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-tdarr.spec = {
                description = "Allow Envoy Gateway proxies to reach tdarr's webUI.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "tdarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8265";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-metrics-ingress-tdarr.spec = {
                description = "Allow Prometheus to scrape tdarr's exporter sidecar (9090).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "tdarr";
                ingress = [
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
                            port = "9090";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Node-worker control channel: the gateway-ingress policy above flips
              # the pod to default-deny ingress, so the tdarr-node workers (same
              # media namespace) need an explicit ingress to 8266 or they cannot
              # register with the server.
              allow-nodeconn-ingress-tdarr.spec = {
                description = "Allow tdarr-node workers to reach the tdarr server's node port (8266).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "tdarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "tdarr-node"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8266";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-tdarr.spec = {
                description = "Allow tdarr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "tdarr";
                egress = [
                  {
                    toEndpoints = [
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "kube-system";
                          "k8s-app" = "kube-dns";
                        };
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                          {
                            port = "53";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # World egress (80/443): the server fetches its plugin repo
              # (github) on boot to populate the plugins folder. Without it the
              # "Updating plugins" step times out (AxiosError 15000ms), leaving
              # the plugins incomplete — e.g. hardwareUtils.test.js missing, which
              # fails the FFmpeg-encoder enumeration on both server and nodes (the
              # nodes inherit the plugin set from the server, so only the server
              # needs egress).
              allow-internet-egress-tdarr.spec = {
                description = "Allow tdarr's server to fetch its plugin repo from the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "tdarr";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "80";
                            protocol = "TCP";
                          }
                          {
                            port = "443";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };

            httpRoutes.tdarr.spec = {
              hostnames = [ (cluster.domainFor "tdarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "tdarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "tdarr";
                      port = 8265;
                    }
                  ];
                }
              ];
            };

            securityPolicies."tdarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "tdarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "tdarr";
                clientID = "tdarr";
                clientSecret.name = "tdarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                # If tdarr's UI is later found to reject a forwarded Bearer token,
                # flip this to false (the arrs forward; the UI is OIDC-gated at the
                # gateway either way).
                forwardAccessToken = true;
              };
            };

            secrets.tdarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.tdarr-oidc-client-secret.sopsRef;
            };
          };
        };

        # Node-worker DaemonSet: one pod per AMD-APU axon node (nodeSelector
        # node.kubernetes.io/amd-gpu), each claiming the node's GPU (amd.com/gpu:
        # 1) to hardware-encode AV1 with the custom registry image. It reads the
        # library over NFS at /data (writable — the node writes the transcode
        # back) and caches the in-flight transcode on a node-local emptyDir at
        # /temp. The node dials the server's control channel
        # (tdarr.media.svc:8266) to register and pull jobs.
        applications.tdarr-node = {
          namespace = "media";

          helm.releases.tdarr-node = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "daemonset";
                pod.nodeSelector."node.kubernetes.io/amd-gpu" = "true";

                containers.main = {
                  image = {
                    inherit (images."json64/tdarr-node") repository digest;
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    inContainer = "true";
                    serverIP = "tdarr.media.svc.cluster.local";
                    serverPort = "8266";
                    # Per-host node name so the server tracks each DaemonSet pod as
                    # its own GPU worker. A static value makes all three register
                    # under one name (server warns "nodeName ... used by multiple
                    # Nodes") and muddles per-node worker assignment + stats.
                    nodeName.valueFrom.fieldRef.fieldPath = "spec.nodeName";
                    nodeType = "mapped";
                    transcodegpuWorkers = "1";
                    transcodecpuWorkers = "0";
                    healthcheckgpuWorkers = "0";
                    healthcheckcpuWorkers = "0";
                  };
                  resources = {
                    requests."amd.com/gpu" = 1;
                    limits."amd.com/gpu" = 1;
                  };
                };
              };

              persistence = {
                # NAS library over NFS, writable: the node writes the finished
                # transcode back into the library.
                data = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [ { path = "/data"; } ];
                };
                # Node-local transcode scratch — in-flight work cache, never
                # leaves the node.
                temp = {
                  type = "emptyDir";
                  globalMounts = [ { path = "/temp"; } ];
                };
              };
            };
          };

          resources.ciliumNetworkPolicies = {
            # tdarr-node dials the server's node-worker control port (8266) in
            # the same media namespace to register and pull jobs.
            allow-nodeconn-egress-tdarr-node.spec = {
              description = "Allow tdarr-node workers to reach the tdarr server node port (8266).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "tdarr-node";
              egress = [
                {
                  toEndpoints = [
                    { matchLabels."app.kubernetes.io/name" = "tdarr"; }
                  ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "8266";
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };

            allow-dns-egress-tdarr-node.spec = {
              description = "Allow tdarr-node to resolve via kube-dns.";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "tdarr-node";
              egress = [
                {
                  toEndpoints = [
                    {
                      matchLabels = {
                        "k8s:io.kubernetes.pod.namespace" = "kube-system";
                        "k8s-app" = "kube-dns";
                      };
                    }
                  ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "53";
                          protocol = "UDP";
                        }
                        {
                          port = "53";
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };

            # Ingress lockdown: network-policy.nix doesn't manage tdarr-node, so
            # restore the default-deny it would otherwise inherit (mirrors
            # unpackerr). The node takes no real inbound; only the host entity
            # (kubelet probes / node-local) is allowed.
            deny-ingress-tdarr-node.spec = {
              description = "Default-deny ingress for tdarr-node (host-only).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "tdarr-node";
              enableDefaultDeny.ingress = true;
              ingress = [ { fromEntities = [ "host" ]; } ];
            };
          };
        };
      };
  };
}
