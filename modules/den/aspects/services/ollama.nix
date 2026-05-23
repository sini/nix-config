{
  lib,
  ...
}:
{
  den.aspects.services.ollama = {
    settings = {
      acceleration = lib.mkOption {
        type = lib.types.enum [
          "rocm"
          "cuda"
          "cpu"
        ];
        default = "cpu";
        description = "GPU acceleration backend";
      };
    };

    nixos =
      {
        host,
        pkgs,
        ...
      }:
      let
        acceleration = host.settings.services.ollama.acceleration;
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

            home = "/cache/var/lib/private/ollama";
            models = "/cache/var/lib/private/ollama/models";

            package =
              if acceleration == "rocm" then
                pkgs.ollama-rocm
              else if acceleration == "cuda" then
                pkgs.ollama-cuda
              else
                pkgs.ollama-cpu;

            environmentVariables = {
              OLLAMA_FLASH_ATTENTION = "true";
              OLLAMA_CONTEXT_LENGTH = "32768";
              OLLAMA_KV_CACHE_TYPE = "q8_0";
              OLLAMA_KEEP_ALIVE = "10m";
              OLLAMA_MAX_LOADED_MODELS = "4";
              OLLAMA_MAX_QUEUE = "64";
              OLLAMA_NUM_PARALLEL = "1";
              OLLAMA_ORIGINS = "*";
            };

            loadModels = [
              "deepcoder:14b"
              "gpt-oss:20b"
              "deepseek-coder:1.3b-instruct-q4_K_M"
              "codellama:7b-instruct-q2_K"
              "qwen2.5-coder:14b"
              "qwen2.5-coder:32b"
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
      };

    persist = {
      directories = [
        {
          directory = "/var/lib/private/ollama";
          user = "ollama";
          group = "ollama";
          mode = "0700";
        }
      ];
    };
  };
}
