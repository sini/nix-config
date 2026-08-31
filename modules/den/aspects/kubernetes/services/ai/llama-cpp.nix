# llama.cpp servers on the axon APUs — OpenAI-compatible inference in-cluster.
#
# The nodes are Ryzen 9 7940HS / Radeon 780M (gfx1103, RDNA3, 12 CU) with
# 2x32 GB DDR5-5600. GPU access needs no new plumbing: the ROCm device plugin
# (hardware.amd-gpu-device-plugin) already advertises `amd.com/gpu: 1` on every
# node, and its Allocate injects /dev/kfd AND /dev/dri/card+renderD — so a pod
# requesting that resource gets the render node Vulkan needs.
#
# Vulkan, not ROCm: gfx1103 is absent from the upstream ROCm image's
# AMDGPU_TARGETS, so that route needs an HSA_OVERRIDE_GFX_VERSION masquerade as
# gfx1102. RADV has no such gap.
#
# On an APU the GPU buys PREFILL, not decode. Decode is bandwidth-bound and the
# iGPU shares the CPU's bus — 89.6 GB/s theoretical — so what matters is bytes
# read per token, which is why both models here are MoE. The APU's compensating
# advantage is CAPACITY: 62 GB of addressable RAM holds models a 24 GB discrete
# card cannot, at full context.
#
# One instance per settings entry, each pinned to its own node by the exclusive
# amd.com/gpu allocation — no anti-affinity needed, and no more instances than
# there are schedulable GPU nodes.
#
# Cluster-internal only. Consumers reach an instance at
# http://llama-cpp-<name>.ai.svc:8080/v1.
{
  den.aspects.kubernetes.services.ai.llama-cpp = {
    k8s-manifests =
      {
        cluster,
        charts,
        images,
        lib,
        ...
      }:
      let
        inherit (cluster.settings.kubernetes.services.ai.llama-cpp) instances;

        port = 8080;

        # One label across every instance, so the network policies and the
        # PodMonitor are written once instead of per instance.
        engineLabel = "den.ai/engine";
        engineValue = "llama-cpp";

        mkRelease = name: inst: {
          chart = charts.bjw-s-labs.app-template;
          values = {
            controllers.main = {
              type = "deployment";

              # One replica, and one is the ceiling: the node's single
              # amd.com/gpu is allocated exclusively, so a second pod could
              # never schedule beside this one. Recreate for the same reason —
              # a RollingUpdate's replacement would wait forever for a GPU the
              # outgoing pod still holds.
              replicas = 1;
              strategy = "Recreate";

              pod.labels.${engineLabel} = engineValue;

              containers.main = {
                image = {
                  inherit (images."ggml-org/llama.cpp") repository digest;
                };

                # llama-server takes its whole configuration from LLAMA_ARG_*,
                # so no args are needed; the image's entrypoint is the server
                # and it presets LLAMA_ARG_HOST=0.0.0.0.
                env = {
                  LLAMA_ARG_HF_REPO = inst.model;
                  LLAMA_ARG_ALIAS = inst.modelAlias;
                  # -hf pulls a multimodal projector alongside the weights
                  # whenever the repo has one. Qwen3.6-35B-A3B is a VL model, so
                  # that is an extra 0.9 GB downloaded, held in RAM, and warned
                  # about on every start ("Qwen-VL models require at minimum 1024
                  # image tokens") for a text-only extraction workload. No-op on
                  # instances whose repo ships no projector.
                  LLAMA_ARG_MMPROJ_AUTO = "0";
                  LLAMA_ARG_PORT = toString port;
                  LLAMA_ARG_CTX_SIZE = toString inst.contextSize;
                  LLAMA_ARG_N_GPU_LAYERS = toString inst.gpuLayers;
                  # Weights land on the PVC below instead of the container
                  # filesystem, so a restart does not re-download tens of GB.
                  LLAMA_CACHE = "/models";
                  # /metrics — the point of this deployment is finding out what
                  # the APU actually does, and this is where the tokens/sec and
                  # prompt-eval timings come from.
                  LLAMA_ARG_ENDPOINT_METRICS = "1";
                };

                probes = {
                  liveness = {
                    enabled = true;
                    type = "HTTP";
                    path = "/health";
                    inherit port;
                  };
                  readiness = {
                    enabled = true;
                    type = "HTTP";
                    path = "/health";
                    inherit port;
                  };
                  # First boot pulls the weights from HuggingFace — 22 GB for
                  # the Qwen instance — before the server answers anything, then
                  # loads them onto the GPU. 30 minutes of headroom so liveness
                  # cannot kill it mid-download.
                  startup = {
                    enabled = true;
                    custom = true;
                    spec = {
                      httpGet = {
                        path = "/health";
                        inherit port;
                      };
                      periodSeconds = 10;
                      failureThreshold = 180;
                    };
                  };
                };

                ports = [
                  {
                    name = "http";
                    containerPort = port;
                  }
                ];

                # amd.com/gpu must appear identically in requests and limits;
                # k8s forbids overcommitting extended resources.
                resources = {
                  requests = {
                    cpu = "500m";
                    memory = "2Gi";
                    "amd.com/gpu" = 1;
                  };
                  limits = {
                    cpu = "6000m";
                    memory = inst.memoryLimit;
                    "amd.com/gpu" = 1;
                  };
                };
              };
            };

            service.main = {
              controller = "main";
              # Pin the in-cluster name to `llama-cpp-<key>`: bjw-s suffixes
              # every service with its identifier once a controller owns >1
              # service (main would become `llama-cpp-qwen-main`), which would
              # dangle hindsight's HINDSIGHT_API_*_LLM_BASE_URL. Same reason
              # shoko.nix pins its own. Keep this byte-identical to the
              # single-service name.
              forceRename = "llama-cpp-${name}";
              ports.http.port = port;
            };

            # Private-network reach on a kubernetes-loadbalancers address, the
            # shoko idiom: BGP-advertised to the LAN, not internet-routable. Lets
            # workstations and off-cluster hosts use these endpoints directly as
            # OpenAI-compatible backends.
            #
            # The assignment name is derived from the instance key, so adding an
            # instance without reserving its address in the cluster's
            # kubernetes-loadbalancers network fails at eval with the missing
            # name — rather than silently coming up unreachable.
            #
            # NOTE: llama-server runs with no API key (it says so at startup:
            # "CORS is set to allow all origins and no API key is set"), so
            # anything on the LAN that can route here can spend GPU time. The
            # CiliumNetworkPolicy below is the only control.
            service.internal = {
              controller = "main";
              type = "LoadBalancer";
              externalTrafficPolicy = "Local";
              annotations."lbipam.cilium.io/ips" = cluster.getAssignment "llama-cpp-${name}-internal";
              ports.http.port = port;
            };

            persistence = {
              # Re-downloadable weights: single-replica storage on purpose,
              # replicating a HuggingFace cache three ways buys nothing.
              models = {
                type = "persistentVolumeClaim";
                accessMode = "ReadWriteOnce";
                size = "30Gi";
                storageClass = "longhorn-single";
                globalMounts = [ { path = "/models"; } ];
              };
            };
          };
        };
      in
      {
        applications.llama-cpp = {
          namespace = "ai";

          helm.releases = lib.mapAttrs' (
            name: inst: lib.nameValuePair "llama-cpp-${name}" (mkRelease name inst)
          ) instances;

          # One PodMonitor for every instance: selected by the shared engine
          # label, with `instance` taken from the per-release app name so the
          # two show up as distinct series rather than colliding.
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "llama-cpp";
                namespace = "ai";
              };
              spec = {
                selector.matchLabels.${engineLabel} = engineValue;
                podMetricsEndpoints = [
                  {
                    port = "http";
                    path = "/metrics";
                    interval = "30s";
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

          # In-cluster egress is covered by the clusterwide
          # allow-internal-egress policy; only the off-cluster path and the
          # ingress need stating. Both select the shared engine label, so they
          # cover every instance without repetition.
          resources.ciliumNetworkPolicies = {
            # Declaring any ingress rule flips these pods to ingress
            # default-deny, so both callers are enumerated. kubectl port-forward
            # is unaffected — that arrives from the node, which Cilium allows.
            allow-ingress-llama-cpp.spec = {
              description = "Allow hindsight and Prometheus to reach llama-cpp (8080).";
              endpointSelector.matchLabels.${engineLabel} = engineValue;
              ingress = [
                {
                  fromEndpoints = [
                    { matchLabels."app.kubernetes.io/name" = "hindsight"; }
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

            # Off-cluster LAN callers reach these over the internal
            # LoadBalancers above. Same reasoning as allow-lan-ingress-shoko:
            # the whole private 10/8 rather than per-host pins, covering both
            # the externalTrafficPolicy=Local source IP and any node SNAT.
            allow-lan-ingress-llama-cpp.spec = {
              description = "Allow private-LAN clients to reach llama-cpp on 8080 over the internal LoadBalancers.";
              endpointSelector.matchLabels.${engineLabel} = engineValue;
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

            # Model download only. Once the PVCs are warm this is dead weight
            # and can be dropped, at the cost of a manual re-seed on any model
            # change.
            allow-huggingface-egress-llama-cpp.spec = {
              description = "Allow llama-cpp to fetch GGUF weights from HuggingFace.";
              endpointSelector.matchLabels.${engineLabel} = engineValue;
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
