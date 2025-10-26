{
  flake.features.ollama.nixos =
    {
      pkgs,
      lib,
      activeFeatures,
      ...
    }:
    let
      amdEnabled = lib.elem "gpu-amd" activeFeatures;
      nvidiaEnabled =
        lib.elem "gpu-nvidia" activeFeatures && !(lib.elem "gpu-nvidia-vfio" activeFeatures);
    in
    {
      services = {
        ollama = {
          enable = true;
          user = "ollama";
          group = "ollama";
          openFirewall = true;

          host = "0.0.0.0";
          port = 11434;

          # home = "/var/lib/ollama";

          package = lib.mkIf amdEnabled pkgs.ollama-rocm;

          acceleration =
            if amdEnabled then
              "rocm"
            else if nvidiaEnabled then
              "cuda"
            else
              null; # Fallback to CPU-only inference
          # rocmOverrideGfx = "11.0.1"; # 7900xtx (gpu-family)

          # TODO for mini PC's with APU's... https://github.com/rjmalagon/ollama-linux-amd-apu
          #rocmOverrideGfx = "10.3.0";

          environmentVariables = {
            # HCC_AMDGPU_TARGET = "gfx1102";
            OLLAMA_FLASH_ATTENTION = "true";
            OLLAMA_CONTEXT_LENGTH = "32768";
            # OLLAMA_CONTEXT_LENGTH = "16384";
            OLLAMA_KV_CACHE_TYPE = "q8_0";
            OLLAMA_KEEP_ALIVE = "10m";
            OLLAMA_MAX_LOADED_MODELS = "4";
            OLLAMA_MAX_QUEUE = "64";
            OLLAMA_NUM_PARALLEL = "1";
            OLLAMA_ORIGINS = "*";
          };

          # https://ollama.com/library
          loadModels = [
            "deepcoder:14b"
            "gpt-oss:20b"
            "deepseek-coder:1.3b-instruct-q4_K_M"
            "codellama:7b-instruct-q2_K"
            "qwen2.5-coder:14b"
            "qwen2.5-coder:32b"
            "qwen2.5-coder:14b"
            "qwen3-coder:30b"
            "qwen3:1.7b"
            "qwen3:8b"
            "qwen3:14b"
            "qwen3:30b"
            "deepseek-coder-v2:16b"
            "codegemma:7b"
            "gemma3:27b"
            "gemma3:12b"
            "gemma3:4b"
          ];
        };
      };

      environment.persistence."/volatile".directories = [
        {
          directory = "/var/lib/private/ollama";
          user = "ollama";
          group = "ollama";
          mode = "0700";
        }
      ];
    };
}
