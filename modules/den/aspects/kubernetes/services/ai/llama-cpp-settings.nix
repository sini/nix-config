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
                Prompt context in tokens (LLAMA_ARG_CTX_SIZE). Both models here
                are natively 262K, far more than an APU sharing 64 GB with the
                rest of the cluster should reserve; KV cache grows linearly with
                this and comes out of the same pool as the weights.
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
        # 22.1 GB of weights + ~1.3 GB KV at 16K + compute buffers.
        memoryLimit = "32Gi";
      };

      "gpt-oss" = {
        model = "ggml-org/gpt-oss-20b-GGUF:MXFP4";
        modelAlias = "gpt-oss-20b";
      };
    };

    description = ''
      llama-server instances to run, keyed by short name. Each becomes a
      Deployment/Service pair `llama-cpp-<key>` in the `ai` namespace, reachable
      at `http://llama-cpp-<key>.ai.svc:8080/v1`.
    '';
  };
}
