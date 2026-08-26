# hipfire (https://github.com/warpfront/hipfire):
# RDNA/CDNA-native LLM inference engine in Rust, serving an OpenAI-compatible
# API. Not a wrapper around llama.cpp/candle/vLLM: its kernel family,
# HFQ/MagnumQuant quant formats and speculative-decode paths are original
# upstream work (see its PRIOR-ART.md).
#
# Engine, packaging and service all come from upstream's own flake, which
# ships:
#   - nixosModules.default: the services.hipfire module — config.toml and
#     models.toml generation, systemd units (a boot-time kernel
#     pre-compile step plus the daemon), ROCm ICD registration and the
#     dedicated service user.
#   - overlays.default: injects rocmPackages built from the flake's pinned
#     nixpkgs (ROCm 7.x). Mandatory: the ROCm 6.4.3 that nixos-25.11-era
#     nixpkgs ship segfaults libamdhip64 on gfx1151 (Strix Halo) during
#     weight upload. The overlay flows into both the package builds and
#     the module's LD_LIBRARY_PATH / ICD wiring, so host and runtime share
#     one ROCm instance.
#
# We follow latest upstream: the input tracks `master`. Upstream's
# flake.lock pins its own nixpkgs + rust-overlay, so `nix flake update
# hipfire` moves the engine forward reproducibly without dragging the
# host's nixpkgs along.
#
# Model acquisition is store-driven: the registry-listed weights are
# fetched content-addressed from HuggingFace and composed into an immutable
# store directory that the daemon reads as HIPFIRE_MODELS_DIR. The daemon's
# resolver uses a local file as-is and never re-downloads, and nothing in
# this aspect mutates the local system at boot — no `hipfire pull` step, no
# unit race, and the model is present by construction. Ephemeral state
# (kernel JIT cache, daemon state) is recreated by upstream's
# hipfire-setup/hipfire-precompile units on every boot, which is the design
# under a wiped /var.
#
# Emits hipfire-endpoints so pi/hermes derive endpoint AND model identity
# instead of hardcoding the host address.
{
  inputs,
  lib,
  ...
}:
{
  flake-file.inputs.hipfire.url = "github:warpfront/hipfire";

  den.aspects.services.ai.hipfire = {
    # Upstream's rocmPackages/hipfire overlay must be part of this host's
    # package set: the upstream module's defaults (pkgs.hipfire,
    # pkgs.rocmPackages.* in LD_LIBRARY_PATH and ICD registration) resolve
    # against it.
    nixpkgs-overlays =
      { inputs', ... }:
      [ inputs'.hipfire.overlays.default ];

    settings = {
      gpuTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "gfx1151"
          "gfx1030"
        ];
        description = ''
          GPU architectures to pre-compile kernels for. The upstream module
          asserts this is non-empty — Nix cannot probe hardware at
          evaluation time. Detect yours:
            rocminfo 2>/dev/null | grep -oP 'amdgcn-amd-amdhsa--\K\S+' | sort -u
        '';
      };

      modelUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://huggingface.co/hipfire-models/qwen3.8-27b/resolve/main/qwen3.8-27b.mq4";
        description = ''
          Registry-listed weights artifact fetched into the store. The URL's
          basename must be the exact file name the upstream model registry
          (registry/v1.json) records for `defaultModel` — that is how the
          daemon's tag-to-file resolution finds it in HIPFIRE_MODELS_DIR.
          Qwen3.8 27B MQ4V2 base tier (quality trunk, native 262K context);
          the registry's XT/MQ3/MQ5/MQ6 variants are one-URL swaps.
        '';
      };

      modelHash = lib.mkOption {
        type = lib.types.str;
        default = "sha256-W7VWpsyEA1I0mVwBfJeRqjlRrR6uTPjIFysOrvOZ5Qc=";
        description = ''
          SRI hash of the artifact. Matches the `sha256` published in the
          upstream registry (5bb556a6…9e507), which `hipfire pull` itself
          verifies against.
        '';
      };

      draftUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "https://huggingface.co/hipfire-models/qwen3.8-27b/resolve/main/qwen38-27b-dflash-mq4.hfq";
        description = ''
          Optional DFlash draft artifact (fetched alongside the target and
          available when `dflashMode` is on/auto). Null (the default) ships
          the target alone — `dflashMode` stays off or auto-degrades without
          a draft. If set, its basename must be the registry file name of
          the draft tag that pairs with `defaultModel`.
        '';
      };

      draftHash = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "sha256-0KdKIyoOIWbYifgj6R4Pv3eNId2WaNfeBVzeywZUAbw=";
        description = "SRI hash of the draft artifact. Required when draftUrl is set.";
      };

      defaultModel = lib.mkOption {
        type = lib.types.str;
        default = "qwen3.8:27b";
        description = ''
          Registry tag pre-warmed on startup (empty = start with no model
          loaded; the daemon then serves on demand). Must be the tag whose
          registry file name is `modelUrl`'s basename, so the pre-warm
          resolves to the store artifact rather than a download.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 11435;
        description = "Port for the OpenAI-compatible API server (upstream default; llama-cpp holds 8080, ollama 11434, ninfer 8081).";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open the API port in the firewall so clients on the LAN/bridge can reach the daemon.";
      };

      maxSeq = lib.mkOption {
        type = lib.types.int;
        default = 32768;
        description = ''
          KV cache physical capacity in tokens (memory.max_seq). The Qwen3.8
          27B models carry a native 262K context; the ceiling actually
          reachable is VRAM-derived — the daemon loads with less if the pool
          cannot hold more. Raise for longer prompts once measured headroom
          allows.
        '';
      };

      maxTokens = lib.mkOption {
        type = lib.types.int;
        default = 32768;
        description = "Per-request output cap applied when a request omits one (generation.max_tokens).";
      };

      temperature = lib.mkOption {
        type = lib.types.float;
        default = 0.3;
        description = "Sampling temperature (upstream default).";
      };

      topP = lib.mkOption {
        type = lib.types.float;
        default = 0.8;
        description = "Nucleus sampling threshold (upstream default).";
      };

      repeatPenalty = lib.mkOption {
        type = lib.types.float;
        default = 1.05;
        description = "Repetition penalty. Keep conservative — upstream notes 1.3+ causes MQ4 gibberish at low temperature.";
      };

      kvCache = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        example = "asym3";
        description = ''
          KV cache quantization mode: auto / q8 / asym4 / asym3 / asym2 /
          turbo / turbo4 / turbo3 / turbo2. Registry entries also carry a
          per-model default (q8) that applies unless overridden here or in
          `perModelSettings`.
        '';
      };

      dflashMode = lib.mkOption {
        type = lib.types.enum [
          "on"
          "off"
          "auto"
        ];
        default = "off";
        description = ''
          DFlash speculative decode. `auto` engages it when a draft is
          available — set `draftUrl` first. `off` (the default) is
          upstream's stock behavior.
        '';
      };

      idleTimeout = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "Seconds before evicting the loaded model from VRAM. 0 = never.";
      };

      extraSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Additional config.toml keys not covered by dedicated options; merged last and can override typed ones.";
      };

      perModelSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = { };
        description = "Per-model overrides written to models.toml, keyed by registry tag.";
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra environment variables (HIPFIRE_*) for the daemon.";
      };

      userService = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run as a user-level systemd service instead of a system service (no dedicated user).";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "hipfire";
        description = "User to run the daemon as (system mode only).";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "hipfire";
        description = "Group to run the daemon as (system mode only).";
      };
    };

    # Endpoint AND model identity: consumers need the exact model tag plus
    # the context/output bounds, not just an address.
    hipfire-endpoints =
      { host, ... }:
      let
        cfg = host.settings.services.ai.hipfire;
      in
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit (cfg)
          port
          maxSeq
          maxTokens
          ;
        modelId = cfg.defaultModel;
        maxContext = cfg.maxSeq;
      };

    nixos =
      {
        host,
        pkgs,
        ...
      }:
      let
        cfg = host.settings.services.ai.hipfire;

        # Content-addressed acquisition: the model lands in the store and is
        # present the moment the closure is. No first-boot download step, and
        # nothing for the unit to race against.
        modelArtifact = pkgs.fetchurl {
          name = baseNameOf cfg.modelUrl;
          url = cfg.modelUrl;
          hash = cfg.modelHash;
        };

        draftArtifact =
          if cfg.draftUrl == null then
            null
          else
            lib.assertMsg "services.ai.hipfire.draftHash is required when draftUrl is set" (cfg.draftHash != "")
              (
                pkgs.fetchurl {
                  name = baseNameOf cfg.draftUrl;
                  url = cfg.draftUrl;
                  hash = cfg.draftHash;
                }
              );

        # Immutable store directory carrying the exact registry file names,
        # so the daemon's tag-to-file resolution finds the artifacts in
        # HIPFIRE_MODELS_DIR and uses them as-is (never re-downloading).
        modelStore = pkgs.symlinkJoin {
          name = "hipfire-models";
          paths = [ modelArtifact ] ++ lib.optionals (draftArtifact != null) [ draftArtifact ];
        };
      in
      {
        imports = [ inputs.hipfire.nixosModules.default ];

        services.hipfire = {
          enable = true;
          inherit (cfg)
            gpuTargets
            port
            openFirewall
            defaultModel
            temperature
            topP
            maxTokens
            maxSeq
            repeatPenalty
            kvCache
            dflashMode
            idleTimeout
            extraSettings
            perModelSettings
            environment
            userService
            user
            group
            ;
          # The store directory stands in for upstream's /var/lib/hipfire
          # models dir: its setup unit's `mkdir -p` is a no-op on the
          # existing store path, and the daemon reads it read-only.
          modelDir = modelStore;
        };
      };
  };
}
