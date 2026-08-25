# llama-cpp — high-performance long-context LLM inference server (llama-server).
#
# Target single CUDA GPU inside MicroVM with 800k (819,200 token) context window.
# TODO: Evaluate Vulkan performance & multi-GPU tensor splitting across hosts later.
#
# Emits llama-cpp-endpoints quirk so consumers (open-webui) can discover instances.
{ lib, ... }:
{
  den.aspects.services.ai.llama-cpp = {
    settings = {
      modelPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to GGUF model file";
      };
      contextSize = lib.mkOption {
        type = lib.types.int;
        default = 262144; # 256K (262,144 tokens) native context fitting GPU VRAM with Q4_K_M
        description = "Maximum context window size in tokens";
      };
      cacheRamMB = lib.mkOption {
        type = lib.types.int;
        default = 49152; # 48 GB CPU System RAM cache allocation for unified KV spillover
        description = "CPU RAM allocated for KV cache spillover in MB";
      };
      kvCacheType = lib.mkOption {
        type = lib.types.str;
        default = "q4_0";
        description = "KV cache tensor quantization (q4_0, q8_0, fp16)";
      };
    };

    llama-cpp-endpoints =
      { host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        port = 8080;
      };

    nixos =
      { host, pkgs, ... }:
      let
        cfg = host.settings.services.ai.llama-cpp;
      in
      {
        # Target single CUDA GPU (RTX 3090 Ti inside MicroVM)
        services.llama-cpp = {
          enable = true;
          package = pkgs.llama-cpp.override { cudaSupport = true; };
          settings = {
            model =
              if cfg.modelPath != null then
                cfg.modelPath
              else
                "/cache/var/lib/private/llama-cpp/models/Qwen3.8-27B-UD-Q4_K_M.gguf";
            ctx-size = cfg.contextSize; # 262,144 tokens
            parallel = 1; # Single slot for max VRAM context allocation
            cache-ram = cfg.cacheRamMB; # 48 GB CPU System RAM for KV spillover
            no-cache-idle-slots = true; # Automatically release idle slots
            cache-type-k = cfg.kvCacheType; # 4-bit KV quantization
            cache-type-v = cfg.kvCacheType;
            n-gpu-layers = 99;
            flash-attn = "on";
            kv-unified = true; # Spill KV cache into system RAM for 800k context
            reasoning-preserve = true; # Retain internal thinking stream for Qwen 3.8 / DeepSeek
            reasoning-budget = 4096;
            batch-size = 2048;
            ubatch-size = 512;
            chat-template-kwargs = "'{\"preserve_thinking\":true}'";
            host = "0.0.0.0";
            port = 8080;
          };
        };

        # Mutex GPU VRAM against Ollama so only one model engine holds VRAM at a time
        systemd.services.llama-cpp = {
          unitConfig = {
            Conflicts = [ "ollama.service" ];
          };
        };

        networking.firewall.allowedTCPPorts = [ 8080 ];
      };
  };
}
