# Hindsight — agent memory engine: retain (LLM fact extraction) + recall
# (hybrid semantic/BM25/graph search) over per-bank Postgres+pgvector storage.
#
# The dataplane API only (`hindsight-api`, the image upstream's own chart
# deploys). The all-in-one `hindsight` image is not used: it bundles an embedded
# postgres and the Next.js control plane, and state belongs in hindsight-pg.
#
# Deployed cluster-internal — no HTTPRoute, no service-domains. Hindsight's
# dataplane exposes no bearer/API-key auth of its own (the only auth env var
# upstream defines is HINDSIGHT_CP_DATAPLANE_API_KEY, which is what the *control
# plane* sends), so external exposure has to be solved at the gateway and is
# deliberately a separate wave. Reach it for now via the ClusterIP service or
# `kubectl -n ai port-forward svc/hindsight 8888`.
#
# Embeddings (BAAI/bge-small-en-v1.5) and reranking
# (cross-encoder/ms-marco-MiniLM-L-6-v2) run in-process on CPU at upstream
# defaults; both models are fetched from HuggingFace on first boot into the
# model-cache PVC, which is why this pod has world:443 egress.
{ den, ... }:
{
  den.aspects.kubernetes.services.ai.hindsight = {
    # Hard dependency, not a coincidence of cluster composition: both LLM
    # endpoints and their model names are read out of this aspect's `instances`.
    includes = [ den.aspects.kubernetes.services.ai.llama-cpp ];

    k8s-manifests =
      {
        cluster,
        charts,
        images,
        lib,
        ...
      }:
      let
        settings = cluster.settings.kubernetes.services.ai.hindsight;

        # An LLM key resolves in one of two spaces: an in-cluster llama-cpp
        # instance, or an off-cluster endpoint declared in externalLlms. Model
        # identity stays defined once, at the endpoint that serves it.
        llamaInstances = cluster.settings.kubernetes.services.ai.llama-cpp.instances;
        externals = settings.externalLlms;

        # Fully qualified for the same reason the postgres DSN is; see the note
        # in hindsight-pg.nix on the short form failing to resolve here.
        resolve =
          key:
          if llamaInstances ? ${key} then
            {
              url = "http://llama-cpp-${key}.ai.svc.cluster.local:8080/v1";
              inherit (llamaInstances.${key}) modelAlias;
              external = null;
            }
          else if externals ? ${key} then
            {
              inherit (externals.${key}) url;
              modelAlias = externals.${key}.model;
              external = externals.${key};
            }
          else
            throw "hindsight: unknown LLM key '${key}' — llama-cpp instances: ${toString (builtins.attrNames llamaInstances)}; externalLlms: ${toString (builtins.attrNames externals)}";

        defaultLlm = resolve settings.defaultLlmInstance;
        retainLlm = resolve settings.retainLlmInstance;

        # Egress rules only for the external endpoints actually in use. An
        # unreferenced externalLlms entry is a declaration, not a hole in the
        # policy.
        usedExternals = lib.filter (e: e != null) [
          defaultLlm.external
          retainLlm.external
        ];

        port = 8888;
        cpPort = 3000;
      in
      {
        applications.hindsight = {
          namespace = "ai";

          helm.releases.hindsight = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Single replica, deliberately. Retain work is claimed in
                # async_operations under HINDSIGHT_API_WORKER_ID below, and the
                # in-process worker (HINDSIGHT_API_WORKER_ENABLED, default true)
                # is the only consumer — a second replica would need the
                # separate worker StatefulSet upstream ships for that case.
                replicas = 1;

                # The image drops to USER hindsight (uid/gid 1000 — `useradd -m`
                # in upstream's Dockerfile, and its own comment says 1000), but a
                # freshly provisioned PVC mounts root-owned 0755. The model cache
                # below lands on one, so the embedder's first write fails with
                # "PermissionError at /home/hindsight/.cache/huggingface".
                # fsGroup makes the kubelet chown the volume to this GID and add
                # it to the container's supplementary groups; OnRootMismatch
                # keeps it from re-walking the whole cache on every start.
                pod.securityContext = {
                  fsGroup = 1000;
                  fsGroupChangePolicy = "OnRootMismatch";
                };

                # Release anything the previous incarnation of this worker was
                # holding. A pod that dies mid-retain (OOM, node loss, the crash
                # loop this deployment already went through) leaves its tasks in
                # 'processing' forever — the document sits in the bank with its
                # facts unextracted, which is silently unreachable by recall.
                # Graceful shutdown releases them; ungraceful termination is the
                # gap this closes.
                #
                # Only safe to do unconditionally because WORKER_ID is pinned and
                # replicas = 1: there is never another live worker whose tasks
                # this could steal. It is `|| true` on purpose — on a first
                # deploy the tables do not exist yet (migrations run in the main
                # container, after this), and a best-effort cleanup must never
                # block the startup that would create them.
                initContainers.release-stale-tasks = {
                  image = {
                    inherit (images."vectorize-io/hindsight-api") repository digest;
                  };
                  command = [
                    "sh"
                    "-c"
                    "hindsight-admin decommission-worker hindsight --yes || echo 'release-stale-tasks: skipped (see error above)'"
                  ];
                  env.HINDSIGHT_API_DATABASE_URL.valueFrom.secretKeyRef = {
                    name = "hindsight-pg-dsn";
                    key = "url";
                  };
                };

                containers.main = {
                  image = {
                    inherit (images."vectorize-io/hindsight-api") repository digest;
                  };

                  env = {
                    HINDSIGHT_API_HOST = "0.0.0.0";
                    HINDSIGHT_API_PORT = toString port;
                    HINDSIGHT_API_LOG_LEVEL = "info";

                    # A worker claims operations under this id and holds them in
                    # 'processing' until it reports back. Left unset it defaults
                    # to the hostname — the pod name — which churns on every
                    # restart, so in-flight work is orphaned under an identity
                    # that no longer exists and cannot be addressed afterwards.
                    #
                    # Pinning it does NOT make recovery automatic: upstream has
                    # no startup reclaim (decommission-worker exists only in the
                    # admin CLI, and its documented use case is "if a worker
                    # crashed while processing tasks"). What pinning buys is a
                    # KNOWN name to release, which the init container does.
                    HINDSIGHT_API_WORKER_ID = "hindsight";

                    HINDSIGHT_API_DATABASE_URL.valueFrom.secretKeyRef = {
                      name = "hindsight-pg-dsn";
                      key = "url";
                    };
                    # Upstream's default, stated explicitly because hindsight-pg
                    # provisions to match it (CREATE EXTENSION vector).
                    HINDSIGHT_API_VECTOR_EXTENSION = "pgvector";

                    # `openai`, not `llamacpp`: upstream's in-process llamacpp
                    # provider needs llama-cpp-python, which the published image
                    # deliberately omits (it fails with ModuleNotFoundError).
                    # Talking to a llama-server over its OpenAI-compatible API is
                    # the supported shape, and upstream's own local-llm compose
                    # example does exactly this.
                    HINDSIGHT_API_LLM_PROVIDER = "openai";
                    HINDSIGHT_API_LLM_BASE_URL = defaultLlm.url;
                    HINDSIGHT_API_LLM_MODEL = defaultLlm.modelAlias;
                    # The openai provider requires this populated even when the
                    # backend ignores it; llama-server runs with no API key set.
                    # Upstream's own example uses the literal "not-needed".
                    HINDSIGHT_API_LLM_API_KEY = "not-needed";

                    # Not a tuning preference — a 15.5-point swing on upstream's
                    # own retain leaderboard (v0.9.2, the version pinned here):
                    # gpt-oss 20B at LOW ranks 4th at 57.8 and 5.1s end to end,
                    # the same model at MEDIUM ranks 14th at 42.3 and 55.2s.
                    # Leaving this unset sends no reasoning parameter at all, and
                    # gpt-oss then runs at its own default — which is medium.
                    HINDSIGHT_API_LLM_REASONING_EFFORT = "low";

                    # Upstream default is false: a retain that hit extraction
                    # errors is reported 'completed' and the dropped facts are
                    # silently unreachable by recall. That is precisely the
                    # failure this deployment exists to stop happening to the
                    # law corpus, so failures are made loud.
                    HINDSIGHT_API_FAIL_ON_EXTRACTION_ERRORS = "true";
                  }
                  # Per-operation override for retain, emitted ONLY when it
                  # actually differs from the default. Pointing both at one
                  # instance and still emitting these would be four env vars
                  # restating the global config — and a reader would reasonably
                  # infer a split that isn't there.
                  // lib.optionalAttrs (settings.retainLlmInstance != settings.defaultLlmInstance) {
                    HINDSIGHT_API_RETAIN_LLM_PROVIDER = "openai";
                    HINDSIGHT_API_RETAIN_LLM_BASE_URL = retainLlm.url;
                    HINDSIGHT_API_RETAIN_LLM_MODEL = retainLlm.modelAlias;
                    HINDSIGHT_API_RETAIN_LLM_API_KEY = "not-needed";
                  };

                  probes = {
                    # /health is the readiness endpoint; /health/live the
                    # liveness one (upstream chart's split).
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/health/live";
                      inherit port;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/health";
                      inherit port;
                    };
                    # First boot downloads the embedder + reranker from
                    # HuggingFace into the (empty) model-cache PVC before the
                    # API serves anything; 10 minutes of headroom keeps the
                    # liveness probe from killing the pod mid-download.
                    startup = {
                      enabled = true;
                      custom = true;
                      spec = {
                        httpGet = {
                          path = "/health";
                          inherit port;
                        };
                        periodSeconds = 10;
                        failureThreshold = 60;
                      };
                    };
                  };

                  ports = [
                    {
                      name = "http";
                      containerPort = port;
                    }
                  ];

                  # ~2Gi resident under load with both local models in-process
                  # (upstream's hardware table); the ceiling leaves room for a
                  # large retain, whose in-flight extraction state is bounded by
                  # HINDSIGHT_API_RETAIN_MEMORY_BUDGET_MB (default 128).
                  resources = {
                    requests = {
                      cpu = "200m";
                      memory = "1Gi";
                    };
                    limits = {
                      cpu = "2000m";
                      memory = "4Gi";
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                # Pin to `hindsight`: bjw-s suffixes every service with its
                # identifier once a controller owns >1 service, so adding the
                # LoadBalancer below would otherwise rename this to
                # `hindsight-main` and move the in-cluster address under every
                # existing consumer. Same reason shoko.nix pins its own.
                forceRename = "hindsight";
                ports.http.port = port;
              };

              # Private-network reach on a kubernetes-loadbalancers address,
              # BGP-advertised to the LAN and not internet-routable — the shoko
              # idiom. This is how workstations and off-cluster agents reach the
              # bank without a public HTTPRoute and without the OIDC gateway,
              # which headless MCP clients cannot complete anyway.
              #
              # NOTE: hindsight's dataplane has no authentication of its own, so
              # anything on the LAN that can route here has full read/write on
              # the bank. The CiliumNetworkPolicy below is the only control.
              service.internal = {
                controller = "main";
                type = "LoadBalancer";
                externalTrafficPolicy = "Local";
                annotations."lbipam.cilium.io/ips" = cluster.getAssignment "hindsight-internal";
                ports.http.port = port;
              };

              persistence = {
                # HuggingFace cache for the local embedder (~130 MB) and
                # reranker (~90 MB), so they are fetched once rather than on
                # every pod start. Upstream mounts the cache at this path.
                model-cache = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "5Gi";
                  storageClass = "longhorn";
                  globalMounts = [ { path = "/home/hindsight/.cache"; } ];
                };
              };
            };
          };

          # Control plane — the Next.js UI over the dataplane API. Separate
          # release rather than a second controller in the one above: it is a
          # different image on a different lifecycle, holds no state, wants no
          # PVC, and should be able to restart without touching the API.
          #
          # It exposes no metrics (upstream: "the control plane (Next.js) does
          # not expose metrics"), so it gets no PodMonitor, and its probes are
          # tcpSocket because it serves no /health.
          helm.releases.hindsight-cp = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                replicas = 1;
                pod.labels."den.ai/component" = "hindsight-cp";

                containers.main = {
                  image = {
                    inherit (images."vectorize-io/hindsight-control-plane") repository digest;
                  };

                  env = {
                    NODE_ENV = "production";
                    HINDSIGHT_CP_HOSTNAME = "0.0.0.0";
                    HINDSIGHT_CP_PORT = toString cpPort;
                    # In-cluster, via the pinned service name.
                    HINDSIGHT_CP_DATAPLANE_API_URL = "http://hindsight.ai.svc.cluster.local:${toString port}";
                    # Bearer the CP sends to the dataplane. Only required when
                    # the API is auth-protected; ours is not, so this is left
                    # unset deliberately rather than set to a placeholder.
                  };

                  probes = {
                    liveness = {
                      enabled = true;
                      custom = true;
                      spec = {
                        tcpSocket.port = cpPort;
                        initialDelaySeconds = 30;
                        periodSeconds = 10;
                      };
                    };
                    readiness = {
                      enabled = true;
                      custom = true;
                      spec = {
                        tcpSocket.port = cpPort;
                        initialDelaySeconds = 10;
                        periodSeconds = 5;
                      };
                    };
                  };

                  ports = [
                    {
                      name = "http";
                      containerPort = cpPort;
                    }
                  ];

                  resources = {
                    requests = {
                      cpu = "50m";
                      memory = "256Mi";
                    };
                    limits = {
                      cpu = "1000m";
                      memory = "1Gi";
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                forceRename = "hindsight-cp";
                ports.http.port = cpPort;
              };

              # Private-network reach, same rationale as the API's.
              service.internal = {
                controller = "main";
                type = "LoadBalancer";
                externalTrafficPolicy = "Local";
                annotations."lbipam.cilium.io/ips" = cluster.getAssignment "hindsight-cp-internal";
                ports.http.port = cpPort;
              };
            };
          };

          # Raw PodMonitor: no typed accessor without a kube-prometheus-stack
          # CRDs bridge, so author it directly (mirrors the monitoring aspect).
          # The API serves Prometheus format at /metrics on its own port.
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "hindsight";
                namespace = "ai";
              };
              spec = {
                selector.matchLabels."app.kubernetes.io/name" = "hindsight";
                podMetricsEndpoints = [
                  {
                    port = "http";
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

          # In-cluster egress (hindsight-pg, kube-dns) is already covered by the
          # clusterwide allow-internal-egress policy (cilium.nix), so only the
          # off-cluster paths and the ingress are enumerated here.
          resources.ciliumNetworkPolicies = {
            # Declaring any ingress rule flips this pod to ingress default-deny.
            # Prometheus is the only legitimate caller in this wave; the gateway
            # is added when the route is.
            allow-metrics-ingress-hindsight.spec = {
              description = "Allow Prometheus to scrape hindsight (8888).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
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
                          port = toString port;
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };

            # The control plane reaches the API from a POD address (172.20/16),
            # which the LAN rule below does not cover — without this the
            # ingress default-deny silently drops it.
            allow-cp-ingress-hindsight.spec = {
              description = "Allow the hindsight control plane to reach the dataplane API (8888).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              ingress = [
                {
                  fromEndpoints = [
                    { matchLabels."app.kubernetes.io/name" = "hindsight-cp"; }
                  ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = toString port;
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };

            # Browser access to the control plane over its own LoadBalancer.
            allow-lan-ingress-hindsight-cp.spec = {
              description = "Allow private-LAN clients to reach the hindsight control plane UI (3000).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight-cp";
              ingress = [
                {
                  fromCIDR = [ "10.0.0.0/8" ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = toString cpPort;
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };

            # Off-cluster LAN callers (workstations, uplink) reach the bank over
            # the internal LoadBalancer above, bypassing the gateway. The whole
            # private 10/8 range rather than a per-host pin: it is portable, the
            # LB address is RFC1918 and not internet-routable, and it covers both
            # the externalTrafficPolicy=Local source (the caller's real IP) and
            # any node SNAT. Mirrors allow-lan-ingress-shoko.
            allow-lan-ingress-hindsight.spec = {
              description = "Allow private-LAN clients to reach hindsight on 8888 over the internal LoadBalancer.";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              ingress = [
                {
                  fromCIDR = [ "10.0.0.0/8" ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = toString port;
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };

            # In-cluster LLM traffic rides the clusterwide allow-internal-egress
            # policy. OFF-cluster endpoints do not: declaring any egress rule
            # puts this pod in egress default-deny, so each external endpoint in
            # use needs naming or Cilium silently drops it. Generated only for
            # endpoints actually referenced by the settings above.
          }
          // lib.optionalAttrs (usedExternals != [ ]) {
            allow-external-llm-egress-hindsight.spec = {
              description = "Allow hindsight to reach off-cluster LLM endpoints (e.g. ninfer on cortex-cuda).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              egress = map (e: {
                toCIDR = [ e.cidr ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = toString e.port;
                        protocol = "TCP";
                      }
                    ];
                  }
                ];
              }) usedExternals;
            };
          }
          // {
            # World egress purely to populate the model cache on first boot.
            # Once the PVC is warm this is dead weight — a candidate to drop, or
            # to replace with an image that bakes the two models in.
            allow-huggingface-egress-hindsight.spec = {
              description = "Allow hindsight to fetch the local embedder/reranker from HuggingFace on first boot.";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              egress = [
                {
                  toEntities = [ "world" ];
                  toPorts = [
                    {
                      ports = [
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
        };
      };
  };
}
