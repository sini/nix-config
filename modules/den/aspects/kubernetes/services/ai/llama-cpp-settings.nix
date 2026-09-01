# Settings for the cluster llama-cpp aspect. Surfaced onto the cluster as
# `cluster.settings.kubernetes.services.ai.llama-cpp.*`; set per cluster via
# `den.clusters.<name>.settings.kubernetes.services.ai.llama-cpp.<key>`.
#
# Distinct from `services.ai.llama-cpp`, the NixOS aspect that runs llama-server
# on a host against a discrete CUDA GPU. Same engine, different substrate.
{ lib, ... }:
{
  # One llama-server per entry. A llama-server process serves exactly one model,
  # and each node advertises exactly one amd.com/gpu which the device plugin
  # allocates exclusively — so an entry here costs a whole node's GPU, and the
  # number of entries cannot exceed the number of schedulable GPU nodes.
  den.aspects.kubernetes.services.ai.llama-cpp.settings.instances = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            model = lib.mkOption {
              type = lib.types.str;
              description = ''
                Model for llama-server's -hf (LLAMA_ARG_HF_REPO), as
                `<user>/<repo>[:quant]`. Always name the quant — llama.cpp's
                documented fallback when it is omitted is "the first file in the
                repo", and these repos also carry BF16 shards and speculative
                draft weights.
              '';
            };

            modelAlias = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = ''
                Name this model answers to over the OpenAI-compatible API
                (LLAMA_ARG_ALIAS). Clients must send exactly this in `model`.
              '';
            };

            contextSize = lib.mkOption {
              type = lib.types.ints.positive;
              default = 16384;
              description = ''
                Prompt context in tokens available to ONE request. Both models
                here are natively 262K, far more than an APU sharing 64 GB with
                the rest of the cluster should reserve; KV cache grows linearly
                with this and comes out of the same pool as the weights.

                This is NOT LLAMA_ARG_CTX_SIZE directly — see parallelSlots.
              '';
            };

            # The defect this option exists to prevent, measured 2026-08-31:
            # llama-server was started with LLAMA_ARG_CTX_SIZE=16384 and no
            # -np, and chose `n_slots = 4, n_ctx_slot = 16384,
            # kv_unified = 'true'` on its own. Under a unified KV cache the
            # 16384 cells are ONE pool shared by all four slots, while each
            # slot is told it has the full 16384 — a 4:1 oversubscription that
            # cannot be seen from the setting that caused it.
            #
            # It does not fail cleanly. The server logs "decode: failed to find
            # free space in the KV cache, retrying with smaller batch size" and
            # walks prefill down 1024 -> 512 -> ... -> 8, silently. During the
            # den-law corpus ingest that fired 305 times in 30 minutes on the
            # serving instance against 0 on the idle one.
            #
            # So contextSize is per-request and the aspect multiplies. The
            # coupling is arithmetic in one place instead of an implicit
            # relationship between one setting and a default chosen elsewhere.
            parallelSlots = lib.mkOption {
              type = lib.types.ints.positive;
              default = 4;
              description = ''
                Concurrent request slots (LLAMA_ARG_N_PARALLEL). Total KV pool
                is contextSize * parallelSlots, so each slot gets a real
                contextSize rather than competing for a shared one.

                Raising this past ~4 buys little on an APU: measured aggregate
                throughput on a 780M was 23.5 tok/s at 1 concurrent request,
                32.4 at 2 and 40.5 at 4 — 1.72x for 4x the load, while
                per-stream rate fell 23.5 -> 10.1. Decode is bandwidth-bound
                and these are fine-grained MoE, so batching amortizes weight
                reads poorly (different sequences activate different experts).
                Add REPLICAS on other nodes instead: each brings its own memory
                bus and scales ~linearly at full per-stream speed.
              '';
            };

            replicas = lib.mkOption {
              type = lib.types.ints.positive;
              default = 1;
              description = ''
                llama-server pods for this instance, load-balanced by the
                ClusterIP service. Each replica takes a whole node's
                amd.com/gpu exclusively, so this is capped by the number of
                schedulable GPU nodes MINUS whatever other instances hold —
                and a replica over that cap sits Pending forever rather than
                failing at eval.

                Each replica gets its own weights volume (the StatefulSet's
                volumeClaimTemplate), so N replicas cost N copies of the model
                on disk.
              '';
            };

            gpuLayers = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 99;
              description = ''
                Layers to offload to the GPU (LLAMA_ARG_N_GPU_LAYERS). 99 means
                "all"; lower it if the Vulkan device heap cannot hold the model,
                0 for CPU-only. Layers left on the CPU still read from the same
                memory bus, so this costs throughput rather than failing.
              '';
            };

            memoryLimit = lib.mkOption {
              type = lib.types.str;
              default = "24Gi";
              description = ''
                Container memory ceiling. The iGPU has no memory of its own —
                weights live in GTT, which is this container's RAM — so this must
                cover the model file plus its KV cache plus compute buffers.

                The KV term is contextSize * parallelSlots, not contextSize.
              '';
            };
          };
        }
      )
    );

    # Two instances, split by what upstream's leaderboards actually measure.
    #
    # retain -> Qwen3.6 35B-A3B: the top open-weight model on the retain board
    # (quality 59.5 / 49%, against 56.3 / 48% for both gpt-oss 20B and the dense
    # Qwen3.8 27B). It is a fine-grained MoE — 256 experts, 8 active, ~3B active
    # of 35B — so despite being the larger file it reads FEWER bytes per token
    # than gpt-oss 20B's 3.6B active, and decode here is bandwidth-bound. That
    # shape also suits a UMA APU specifically: on a discrete card a 256-expert
    # MoE that does not fit thrashes PCIe fetching cold experts, whereas here
    # every expert is equally resident in the one memory pool.
    #
    # reflect -> gpt-oss 20B: rank 2 of 21 on the reflect board at 86.3, 0.3
    # behind gpt-oss-120b which will not fit. No Qwen model appears on the
    # reflect board at all, so using 35B-A3B there would have nothing behind it.
    default = {
      qwen = {
        model = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_M";
        modelAlias = "qwen3.6-35b-a3b";
        # 22.1 GB of weights + ~5.2 GB KV (16K x 4 slots) + compute buffers.
        memoryLimit = "40Gi";
      };

      "gpt-oss" = {
        model = "ggml-org/gpt-oss-20b-GGUF:MXFP4";
        modelAlias = "gpt-oss-20b";
        # 12 GB of weights + KV for the full 4-slot pool + compute buffers.
        memoryLimit = "32Gi";
      };
    };

    description = ''
      llama-server instances to run, keyed by short name. Each becomes a
      Deployment/Service pair `llama-cpp-<key>` in the `ai` namespace, reachable
      at `http://llama-cpp-<key>.ai.svc:8080/v1`.
    '';
  };
}
