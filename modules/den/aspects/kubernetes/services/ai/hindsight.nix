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
{
  den.aspects.kubernetes.services.ai.hindsight = {
    k8s-manifests =
      {
        cluster,
        charts,
        images,
        lib,
        ollama-endpoints,
        ...
      }:
      let
        settings = cluster.settings.kubernetes.services.ai.hindsight;

        # Extraction runs on an ollama host outside the cluster, discovered via
        # the quirk (sorted for a stable pick when the fleet grows a second
        # one). Only forced when extractionBaseUrl is left to derive.
        ollamaHosts = builtins.sort (a: b: a.hostname < b.hostname) ollama-endpoints;
        ollamaHost =
          if ollamaHosts == [ ] then
            throw "hindsight: no ollama-endpoints in this environment — set settings.kubernetes.services.ai.hindsight.extractionBaseUrl"
          else
            lib.head ollamaHosts;

        extractionBaseUrl =
          if settings.extractionBaseUrl != null then
            settings.extractionBaseUrl
          else
            "http://${ollamaHost.ip}:${toString ollamaHost.port}/v1";

        port = 8888;
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

                containers.main = {
                  image = {
                    inherit (images."vectorize-io/hindsight-api") repository digest;
                  };

                  env = {
                    HINDSIGHT_API_HOST = "0.0.0.0";
                    HINDSIGHT_API_PORT = toString port;
                    HINDSIGHT_API_LOG_LEVEL = "info";

                    # A worker claims operations under this id and holds them
                    # until it reports back. Left unset it defaults to the pod
                    # name, which churns on every restart, and in-flight work is
                    # then orphaned under a worker identity that no longer
                    # exists — recoverable only by an external reaper. Pinning
                    # it means a restarted pod is the same worker.
                    HINDSIGHT_API_WORKER_ID = "hindsight";

                    HINDSIGHT_API_DATABASE_URL.valueFrom.secretKeyRef = {
                      name = "hindsight-pg-dsn";
                      key = "url";
                    };
                    # Upstream's default, stated explicitly because hindsight-pg
                    # provisions to match it (CREATE EXTENSION vector).
                    HINDSIGHT_API_VECTOR_EXTENSION = "pgvector";

                    HINDSIGHT_API_LLM_PROVIDER = "ollama";
                    HINDSIGHT_API_LLM_BASE_URL = extractionBaseUrl;
                    HINDSIGHT_API_LLM_MODEL = settings.extractionModel;

                    # Upstream default is false: a retain that hit extraction
                    # errors is reported 'completed' and the dropped facts are
                    # silently unreachable by recall. That is precisely the
                    # failure this deployment exists to stop happening to the
                    # law corpus, so failures are made loud.
                    HINDSIGHT_API_FAIL_ON_EXTRACTION_ERRORS = "true";
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

            # Retain-path egress to the fleet's ollama hosts (off-cluster LAN),
            # pinned per host rather than opened to the LAN range.
            allow-extraction-egress-hindsight.spec = {
              description = "Allow hindsight to reach the ollama extraction endpoint(s).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "hindsight";
              egress = map (e: {
                toCIDR = [ "${e.ip}/32" ];
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
              }) ollamaHosts;
            };

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
