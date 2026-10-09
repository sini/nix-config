# llama-cpp — high-performance long-context LLM inference server (llama-server).
#
# Target single CUDA GPU inside MicroVM. Context is bounded by VRAM: stock
# llama.cpp has no host-RAM streaming for ACTIVE KV, so the ceiling is what the
# card holds at the configured cache-type-k/v (see contextSize).
# TODO: Evaluate Vulkan performance & multi-GPU tensor splitting across hosts later.
#
# Emits llama-cpp-endpoints quirk so consumers (open-webui) can discover instances.
{ lib, ... }:
let
  # Hashes are the `lfs.oid` HuggingFace reports for each file. `alias` is the
  # id llama-server answers to; `settings` are extra llama-server flags.
  models = {
    # 13,792,639,168 bytes.
    gpt-oss-20b = {
      url = "https://huggingface.co/unsloth/gpt-oss-20b-GGUF/resolve/main/gpt-oss-20b-F16.gguf";
      hash = "sha256-Tk+c2I1kVuTziecmLspKjVZSEeKyLs6cp6hVYWj/PGY=";
      alias = "gpt-oss-20b";
      # reasoning_effort IS harmony's live knob, and it is pinned here
      # rather than left to each caller: this instance exists to augment
      # the cluster's llama-cpp pool, whose caller is hindsight's retain
      # loop. Retain is prefill-bound extraction -- 7642 tokens in for 67
      # out -- so thinking is latency that buys nothing. Unset does NOT
      # mean off: harmony defaults to medium, which is how a 200-token
      # budget came back here as 200 tokens of reasoning_content and an
      # EMPTY content field. The quotes are load-bearing; the upstream
      # module renders ExecStart with toString, not escapeShellArgs, so
      # systemd does the quote parsing.
      settings.chat-template-kwargs = "'{\"reasoning_effort\":\"low\"}'";
    };
    # club-3090's single-card 262K profile (llamacpp/qwen38-27b-single-iq4xs):
    # q4_0 KV is what fits 262,144 beside 14.3 GB of weights; q8_0 fits 131,072.
    qwen38-27b-iq4xs = {
      url = "https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-UD-IQ4_XS.gguf";
      hash = "sha256-QPrEBQ6UA5fb8TCHr9UPRzShGAW/nWXvjd10g0cOYZk=";
      alias = "qwen3.8-27b";
      settings.reasoning-format = "deepseek";
    };
    # 22.4 GB: fits the card whole.
    qwen36-35b-a3b-q4kxl = {
      url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
      hash = "sha256-cHpVqKQ5fs3kTeDEmdPmjBrR0kDR2mWCa0lJ0QQ/RFA=";
      alias = "qwen3.6-35b-a3b";
      settings.reasoning-format = "deepseek";
    };
    # 31.8 GB: needs n-cpu-moe to hold some experts in host RAM.
    qwen36-35b-a3b-q6kxl = {
      url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf";
      hash = "sha256-9rbG1c+m8A2WTut63SjrFM50gXNNUGuQaBAHZ4zSxIQ=";
      alias = "qwen3.6-35b-a3b";
      settings.reasoning-format = "deepseek";
    };
  };
in
{
  den.aspects.services.ai.llama-cpp = {
    settings = {
      model = lib.mkOption {
        type = lib.types.enum (lib.attrNames models);
        default = "gpt-oss-20b";
        description = "The GGUF fetched into the store, by name from the catalogue at the top of this file.";
      };
      parallel = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = "Slots (`--parallel`). With kv-unified they share one ctx-size pool.";
      };
      nCpuMoe = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.unsigned;
        default = null;
        description = "`--n-cpu-moe`: keep the experts of the first N layers in host RAM. For a MoE that does not fit the card.";
      };
      batchSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2048;
        description = "`--batch-size`.";
      };
      ubatchSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 512;
        description = "`--ubatch-size`. Raising it with offloaded experts trades decode for prefill (the r/hermesagent report: 4096 lifted prefill from ~600 to ~1,900 tok/s).";
      };
      modelPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Escape hatch for an out-of-band GGUF on the llama-cpp share. `null`
          (the default) uses the store artifact fetched from `modelUrl`, so the
          model is content-addressed and present by construction rather than
          left to a manual download that the unit would fail without — the same
          arrangement services.ai.ninfer uses.
        '';
      };
      contextSize = lib.mkOption {
        type = lib.types.int;
        # gpt-oss-20b's trained window, and its ceiling: max_position_embeddings
        # is 131,072, reached by YaRN at factor 32 over a 4,096 original. The
        # previous 262,144 was Qwen3.8-27B's window carried over unchanged, i.e.
        # double what this model was trained for — asking for it does not fail,
        # it extrapolates, which is the silent-degradation shape rather than a
        # loud one.
        default = 131072;
        description = "Maximum context window size in tokens";
      };
      cacheRamMB = lib.mkOption {
        type = lib.types.int;
        default = 49152;
        description = ''
          `--cache-ram`: host budget for llama.cpp's PROMPT cache (saved slot
          state), not a spillover path for active KV. It buys prompt reuse
          across turns, which is what an agent loop needs; it does not raise
          the context ceiling.
        '';
      };
      kvCacheType = lib.mkOption {
        type = lib.types.str;
        default = "f16";
        description = ''
          `--cache-type-k`/`-v`. Unquantized by default because gpt-oss-20b
          does not need the compression: only 12 of its 24 layers use full
          attention (the rest slide at window 128) over 8 KV heads x 64 dim, so
          the whole 131,072-token cache is small.

          Measured on cortex-cuda's 24,564 MiB card at ctx-size 131072, model
          resident: f16 sits at 15,660 MiB (8,904 MiB free), q8_0 at 14,410 MiB.
          The previous q4_0 was carried over from the Qwen3.8-27B profile, where
          the cache genuinely was the binding constraint — here it spent
          accuracy to reclaim headroom that was never contended.
        '';
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
        entry = models.${cfg.model};
        modelArtifact = pkgs.fetchurl {
          inherit (entry) url hash;
          name = baseNameOf entry.url;
        };
      in
      {
        # Target single CUDA GPU (RTX 3090 Ti inside MicroVM)
        services.llama-cpp = {
          enable = true;
          package = pkgs.llama-cpp.override { cudaSupport = true; };
          settings =
            entry.settings or { }
            // lib.optionalAttrs (cfg.nCpuMoe != null) { n-cpu-moe = cfg.nCpuMoe; }
            // {
              model = if cfg.modelPath != null then cfg.modelPath else "${modelArtifact}";
              ctx-size = cfg.contextSize;
              inherit (cfg) parallel;
              # `--cache-idle-slots` is enabled by default and is what actually
              # populates the budget above; the aspect used to pass
              # `--no-cache-idle-slots` alongside it, reserving 48 GiB of prompt
              # cache and then switching off the only thing that fills it. Left at
              # the default deliberately: with parallel = 1 a second conversation
              # evicts the first, and saving the idle slot is what keeps the next
              # turn from re-prefilling the whole transcript.
              cache-ram = cfg.cacheRamMB; # host prompt-cache budget (not active-KV spillover)
              cache-type-k = cfg.kvCacheType;
              cache-type-v = cfg.kvCacheType;
              n-gpu-layers = 99;
              flash-attn = "on";
              kv-unified = true; # one KV buffer shared across sequences (not host spillover)
              # No reasoning-preserve, and no preserve_thinking in
              # chat-template-kwargs: both were Qwen3.8 carry-overs that
              # gpt-oss cannot honour. The server rejects the flag out loud
              # at startup -- "chat template does NOT support preserving
              # reasoning, --reasoning-preserve has no effect" -- while the
              # template kwarg was accepted and silently dropped, which is
              # the worse of the two failures.

              # gpt-oss-20b answers to the same name the in-cluster instances
              # answer to (kubernetes.services.ai.llama-cpp.instances.gpt-oss.modelAlias),
              # so a client addressing the pool reaches this host with its `model`
              # field unchanged. Without an alias the only id llama-server accepts
              # is the store path of the GGUF, which changes per build.
              inherit (entry) alias;

              reasoning-budget = 4096; # force-close a runaway thought (upstream default -1 is unbounded)
              batch-size = cfg.batchSize;
              ubatch-size = cfg.ubatchSize;
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
