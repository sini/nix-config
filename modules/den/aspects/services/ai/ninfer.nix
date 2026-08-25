# NInfer-3090 (https://github.com/Don-Chad/ninfer-3090):
# SM86-only CUDA inference engine for Qwen3.8-27B, serving OpenAI Chat /
# Responses and Anthropic Messages from one resident engine.
#
# Targets the RTX 3090 Ti (10de:2203, GA102, sm_86) passed through to the
# cortex-cuda guest. The upstream flake pins its own nixpkgs (CUDA 12.9 +
# gcc13) because nvcc 12.9 rejects the gcc15 default stdenv, so the package is
# taken from that flake rather than rebuilt against the guest's channel.
#
# Weights, KV pool and CUDA graphs do not fit alongside another engine on one
# 24 GB card, so the unit conflicts with llama-cpp/ollama and does NOT
# auto-start: `systemctl start ninfer` swaps the resident engine, and starting
# llama-cpp swaps it back.
#
# Emits ninfer-endpoints so pi/hermes derive endpoint AND model identity
# instead of hardcoding the guest address.
{ inputs, lib, ... }:
{
  flake-file.inputs.ninfer-3090 = {
    url = "github:Don-Chad/ninfer-3090/release/v0.6.0-rtx3090";
  };

  den.aspects.services.ai.ninfer = {
    settings = {
      modelUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://huggingface.co/neroued/Qwen3.8-27B-NInfer/resolve/main/qwen3_8_27b.ninfer";
        description = "Upstream .ninfer artifact fetched into the store.";
      };
      modelHash = lib.mkOption {
        type = lib.types.str;
        default = "sha256-7sOVZJk9bpx9Xjgzgqdg8JNGXJ0WPsmhvWuAGZUUvz4=";
        description = ''
          SRI hash of the artifact. Matches the `lfs.oid` HuggingFace reports
          for the file and the `SHA256SUMS` published beside it
          (eec39564…14bf3e), which agree.
        '';
      };
      modelPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Escape hatch for an out-of-band artifact on the ninfer share. `null`
          (the default) uses the store artifact fetched from `modelUrl`, so the
          model is content-addressed and present by construction rather than
          left to a manual download that the unit would fail without.
        '';
      };
      modelId = lib.mkOption {
        type = lib.types.str;
        default = "qwen3.8-27b";
        description = ''
          Public model alias (`--model-id`). NInfer rejects a request whose
          `model` field does not equal this string, so it is emitted on the
          ninfer-endpoints quirk and consumers must send exactly this value.
        '';
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8081;
        description = "Listen port. Deliberately not llama-cpp's 8080 so both stay addressable in client config while alternating on the GPU.";
      };
      maxContext = lib.mkOption {
        type = lib.types.int;
        default = 238720; # 3730 pages x 64 tokens
        description = ''
          Per-sequence logical context ceiling (`--max-context`), measured on
          a 24 GB card under every other default here. This value is
          kvDtype-DEPENDENT; the measured ceilings on this hardware are, with
          `--kv-capacity auto` (i.e. holding back 1 GiB of headroom):

            int8  + MTP3 + graphs   150912
            rk8v4 + MTP3 + graphs   198720
            int8,   no MTP/graphs   186944
            rk8v4,  no MTP/graphs   247040

          Note rk8v4 WITH speculation beats int8 WITHOUT it, so buying context
          by disabling MTP/CUDA graphs is never the right trade here.

          The default goes beyond all of those because kvCapacity reserves
          explicitly rather than automatically, reclaiming the headroom:
          238720 tokens, validated by a real 154,719-token prefill. Keep this
          equal to kvCapacity.

          Sizing is a deterministic page calculation rather than allocation
          probing, so these boundaries are reproducible rather than lucky.
          Lowering kvDtype back to int8 without also lowering this value makes
          startup fail loudly (the KV pool cannot hold one full sequence).
        '';
      };
      kvCapacity = lib.mkOption {
        type = lib.types.str;
        default = "238720";
        description = ''
          Shared KV pool sizing (`--kv-capacity`). Must equal maxContext at
          concurrency 1; `auto` instead sizes the pool from VRAM left after
          weights while holding back 1 GiB of headroom.

          We reserve explicitly rather than using `auto` because that 1 GiB
          exists to tolerate OTHER GPU consumers, and this guest is a
          dedicated headless passthrough VM (1 MiB used at idle). Reclaiming
          it takes 198720 -> 238720, at 75 MiB physically free.

          That tight profile is safe here for a measured reason: ninfer
          reserves its complete runtime layout at STARTUP, so free VRAM is
          unchanged between idle and a 154,719-token prefill. If it starts, it
          runs. The corollary is that ANY additional GPU consumer on this VM
          (a second model, --vision, raising maxConcurrency) will fail — set
          this to `auto` before adding one.
        '';
      };
      kvDtype = lib.mkOption {
        type = lib.types.enum [
          "bf16"
          "int8"
          "rk8v4"
        ];
        default = "rk8v4";
        description = ''
          KV-cache storage, and the main context/quality dial.

          Measured on this hardware: rk8v4 buys +31.7% context (150912 ->
          198720) for -4% decode (96.2 -> 92.3 tok/s) and no prefill cost
          (1121 -> 1123 tok/s). That reproduces upstream's ~32% context and
          ~2% decode figures.

          It is nonetheless UPSTREAM-FLAGGED AS LOSSY: their matched coding
          test had the rk8v4 answer introduce a faulty nested-rollback design
          the int8 answer avoided. Keys stay 8-bit and only values drop to
          4-bit, so attention routing is unaffected — but if generated code
          quality regresses, set this to `int8` and drop maxContext to 150912.
        '';
      };
      maxConcurrency = lib.mkOption {
        type = lib.types.ints.between 1 8;
        default = 1;
        description = "Concurrently admitted requests (`--max-concurrency`). 1 gives the lowest latency and the largest per-request KV entitlement.";
      };
      draftTokens = lib.mkOption {
        type = lib.types.ints.between 0 5;
        default = 3;
        description = ''
          MTP speculative draft window. 0 disables speculative decoding.

          3 is not a free choice at the current context: raising it to 5 grows
          the Engine runtime reservation past the explicit KV pool and startup
          is REJECTED. Lower maxContext/kvCapacity first if you want a wider
          draft window.
        '';
      };
      prefillChunk = lib.mkOption {
        type = lib.types.int;
        default = 1024;
        description = ''
          Text-prefill chunk size (`--prefill-chunk`). Forced by the explicit
          KV reservation — 2048 and 4096 both fail to start at the current
          context, same runtime-reservation rejection as a wider draft window.

          Measured to cost nothing: at a context where 4096 does fit, it
          prefills 15,523 tokens in 13.66s against 13.84s for 1024 (~1%,
          noise). Not a lever worth reclaiming context for.
        '';
      };
      maxTokens = lib.mkOption {
        type = lib.types.int;
        default = 32768;
        description = "Output limit applied when a request omits one (`--default-max-tokens`).";
      };
      preserveThinking = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Keep reasoning from closed assistant turns in later prompts (`--preserve-thinking`).";
      };
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Start at boot. Off by default because the unit conflicts with
          llama-cpp/ollama over the single GPU — leaving it off keeps the
          incumbent engine resident and makes ninfer an explicit
          `systemctl start ninfer` swap.
        '';
      };
    };

    # Endpoint AND model identity: consumers need the exact `--model-id` and
    # the context/output bounds, not just an address.
    ninfer-endpoints =
      { host, ... }:
      let
        cfg = host.settings.services.ai.ninfer;
      in
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit (cfg)
          port
          modelId
          maxContext
          maxTokens
          ;
      };

    nixos =
      { host, pkgs, ... }:
      let
        cfg = host.settings.services.ai.ninfer;
        ninfer = inputs.ninfer-3090.packages.${pkgs.stdenv.hostPlatform.system}.ninfer;

        # Content-addressed acquisition: the guest mounts the host's /nix/store
        # over virtiofs, so a store path is readable in the VM and the model is
        # present the moment the closure is. No first-boot download step, and
        # nothing for the unit to race against.
        modelArtifact = pkgs.fetchurl {
          name = "qwen3_8_27b.ninfer";
          url = cfg.modelUrl;
          hash = cfg.modelHash;
        };
        model = if cfg.modelPath != null then cfg.modelPath else "${modelArtifact}";

        args = [
          "${ninfer}/bin/ninfer-serve"
          model
          "--host"
          "0.0.0.0"
          "--port"
          (toString cfg.port)
          "--model-id"
          cfg.modelId
          "--max-context"
          (toString cfg.maxContext)
          "--kv-capacity"
          cfg.kvCapacity
          "--kv-dtype"
          cfg.kvDtype
          "--max-concurrency"
          (toString cfg.maxConcurrency)
          "--prefill-chunk"
          (toString cfg.prefillChunk)
          "--default-max-tokens"
          (toString cfg.maxTokens)
        ]
        ++ lib.optionals (cfg.draftTokens > 0) [
          "--spec"
          "mtp"
          "--draft-tokens"
          (toString cfg.draftTokens)
          "--lm-head-draft"
        ]
        ++ lib.optional cfg.preserveThinking "--preserve-thinking";
      in
      {
        # `ninfer` CLI for one-shot generation against the same artifact. The
        # upstream download helper is deliberately absent: acquisition is the
        # store's job, not an operator's.
        environment.systemPackages = [ ninfer ];

        users.groups.ninfer = { };
        users.users.ninfer = {
          group = "ninfer";
          isSystemUser = true;
        };

        systemd.services.ninfer = {
          description = "NInfer-3090 inference server (Qwen3.8-27B, sm_86)";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = lib.optional cfg.autoStart "multi-user.target";

          # One 24 GB card holds one engine: starting this stops the others.
          conflicts = [
            "llama-cpp.service"
            "ollama.service"
          ];

          # libcuda.so.1 ships with the NVIDIA driver, not the CUDA toolkit.
          environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";

          serviceConfig = {
            ExecStart = lib.escapeShellArgs args;
            User = "ninfer";
            Group = "ninfer";
            Restart = "on-failure";
            RestartSec = 5;
          };
        };

        networking.firewall.allowedTCPPorts = [ cfg.port ];
      };

    cache = {
      directories = [
        {
          directory = "/var/lib/private/ninfer";
          user = "ninfer";
          group = "ninfer";
          mode = "0700";
        }
      ];
    };
  };
}
