# HyperQwen (https://github.com/syv-ai/HyperQwen): a patched vLLM serving
# Qwen3.8-27B W4A16 on one 24 GB card, from upstream's prebuilt image.
#
# Every input is pinned here: the image by digest, the base checkpoint and the
# DFlash2 drafter file by file at a Hub revision. The image is unpacked into a
# rootfs in the store and run with `podman --rootfs` (the guest mounts the
# host's store), so nothing is pulled into the guest's tmpfs root. The base
# checkpoint is copied once onto the hyperqwen share, where upstream's
# `prepare` requantizes it in place on first start (CPU, minutes).
#
# One engine per card: the unit conflicts with ninfer/llama-cpp/ollama and is
# started explicitly.
{ lib, ... }:
let
  hubFiles =
    pkgs: repo: rev: files:
    pkgs.linkFarm "${baseNameOf repo}-${builtins.substring 0 7 rev}" (
      lib.mapAttrsToList (path: hash: {
        name = path;
        path = pkgs.fetchurl {
          url = "https://huggingface.co/${repo}/resolve/${rev}/${path}";
          name = baseNameOf path;
          inherit hash;
        };
      }) files
    );
in
{
  den.aspects.services.ai.hyperqwen = {
    settings = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 18020;
        description = "Listen port.";
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          SPEC = "mtp";
        };
        description = ''
          Launcher knobs (single-user/start_qwen.sh): SPEC (mtp|dflash2),
          CTX (fast|long|huge), DFLASH_TOKENS, PREFIX_CACHE, MAX_LEN, ...
        '';
      };
      template = lib.mkOption {
        type = lib.types.enum [
          "stock"
          "froggeric"
        ];
        default = "stock";
        description = "`froggeric` serves froggeric/Qwen-Fixed-Chat-Templates v22.5 via `--chat-template`.";
      };
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Start at boot. Off: the unit conflicts with every other engine over the single GPU.";
      };
      clients = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Source addresses admitted to the port. Clients also need the API key (`hyperqwen/api-key.age` in the environment's secretPath).";
      };
    };

    nixos =
      {
        config,
        environment,
        host,
        pkgs,
        ...
      }:
      let
        cfg = host.settings.services.ai.hyperqwen;
        dir = "/cache/var/lib/private/hyperqwen";

        image = pkgs.dockerTools.pullImage {
          imageName = "ghcr.io/syv-ai/hyperqwen";
          imageDigest = "sha256:f761ce93d19e6c5a5dfbfb36d8eb98bf7f52fd09cd456465ed14ffcc673b0ffe"; # sha-3acb93f
          finalImageTag = "sha-3acb93f";
          hash = "sha256-+N7uldVJiwpWoh2XOY9v//TCEBFzX6Kuvo8I65gKVCs=";
        };
        # rootfs/ plus the image's environment, which --rootfs does not apply.
        bundle =
          pkgs.runCommand "hyperqwen-bundle"
            {
              nativeBuildInputs = [
                pkgs.skopeo
                pkgs.python3
              ];
            }
            ''
              export HOME=$TMPDIR
              skopeo --insecure-policy copy docker-archive:${image} dir:$TMPDIR/img
              python3 ${./oci-unpack.py} $TMPDIR/img $out
            '';

        base =
          hubFiles pkgs "dbirks/Qwen3.8-27B-W4A16-AutoRound" "1f05c441c4e64ae0549de44fa9ea5a6d43610314"
            {
              "chat_template.jinja" = "sha256-w8+eNKv0+eNsLXIWWqnBMtPipyW2wlhqqjqK+deoEEE=";
              "config.json" = "sha256-MXbo7x+KahHKGJQ2qK2SRZc9QgpOtazKZ74/sKXS+Yw=";
              "generation_config.json" = "sha256-GkULdaVL+eb/3Ggdi3ZNRTBh3S0nHfM/z+1GlJtnw94=";
              "model-00001-of-00007.safetensors" = "sha256-ayrcTxuTOG7t0DOmLGMiG/heeJwJraj/Q5OcVenwYlA=";
              "model-00002-of-00007.safetensors" = "sha256-oiP6SHg0dJoU2G1Vivmk1Xmbeb6bwove+kPu0FXRBXg=";
              "model-00003-of-00007.safetensors" = "sha256-hxlWesgidorGGHKJRgTTpNE/LtvSLJvTxGgOvIPiTKU=";
              "model-00004-of-00007.safetensors" = "sha256-j6+NSlfGm5uW4nxOq/G6DKrdPUg0TW9l3xfzDaKn5uM=";
              "model-00005-of-00007.safetensors" = "sha256-CZS7jZHAfO78S//9Ont/0RDMm9POhlvcsoIavwKgL6s=";
              "model-00006-of-00007.safetensors" = "sha256-VaFO550+WmWocx2JQm9N9Hfovcfap5dtQSVNivuUMvA=";
              "model-00007-of-00007.safetensors" = "sha256-aGbPitzMxMxqAOdLwCXxp3T7UhA7cPJnTQKIJylRpzM=";
              "model.safetensors.index.json" = "sha256-Q7MP/R4vlAoI4uoD9gOa0mAIlJr3QViFW+7sKyzXmoY=";
              "model_extra_tensors.safetensors" = "sha256-HYJoqoWs4JOlYePntjudOQ2sHNVakM1VtexQnDydqf4=";
              "processor_config.json" = "sha256-2J70nOnNN/v1EBWOE8HvBj2ShkEcHskEmTLb4EhxQ7E=";
              "quantization_config.json" = "sha256-LzEiqlfdLzX9qOCPPhwMpOFrcqbto/JqQ1RV3+f9LVA=";
              "tokenizer.json" = "sha256-BrlQk1LSr1A4GrIkfgg7gNMtXAq6kcJyyp/3Kbag5SM=";
              "tokenizer_config.json" = "sha256-X3qg2BAADEoJQLNcjxblbDQ5Jg/MwToyGCbrw8zyUB8=";
            };
        dflash2 =
          hubFiles pkgs "syvai/Qwen3.8-27B-DFlash2-W4A16" "4d30ec736ffc6b8688dc2ae2b502d9b48bdec279"
            {
              "config.json" = "sha256-YdYnb+jXYpUjLLAtJsuw0pwlVlkR9QRB53nIjJIgxVY=";
              "model.safetensors" = "sha256-7CaZbmoHRate24VxFyIM4eIZrVJPcebhSbcDgElH2Oc=";
            };
        froggeric = pkgs.fetchurl {
          url = "https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates/resolve/855bffc49448e299789730ff92c9b8d834d6cc14/chat_template.jinja";
          name = "froggeric-v22.5.jinja";
          hash = "sha256-5XaEuuQVYhGlVHPFpjvpdqQFo3q1vlrg5avx31NJxLI=";
        };

        # A store path is read-only and prepare rewrites the checkpoint in place,
        # so each is copied once per pinned revision.
        seed = src: name: ''
          if [ ! -e ${dir}/models/${name}/.seeded-${baseNameOf src} ]; then
            rm -rf ${dir}/models/${name}
            mkdir -p ${dir}/models/${name}
            cp -L --no-preserve=mode ${src}/* ${dir}/models/${name}/
            touch ${dir}/models/${name}/.seeded-${baseNameOf src}
          fi
        '';
        env = {
          PORT = toString cfg.port;
          HOST = "0.0.0.0";
          # The fast variant is an unpinned Hub download; prepare skips it.
          FAST_VARIANT = "0";
          HF_HUB_OFFLINE = "1";
        }
        // lib.optionalAttrs (cfg.template == "froggeric") {
          EXTRA_ARGS = "--chat-template /templates/froggeric.jinja";
        }
        // cfg.env;
      in
      {
        # verify.sh refuses a network bind without a key. A consumer declares the same
        # rekeyFile and generator, so agenix-rekey gives it the same cleartext.
        age.secrets = {
          hyperqwen-api-key = {
            rekeyFile = environment.secretPath + "/hyperqwen/api-key.age";
            intermediary = true;
            generator.script = "hex";
          };
          hyperqwen-env = {
            generator.dependencies = [ config.age.secrets.hyperqwen-api-key ];
            settings.keys = [ "VLLM_API_KEY" ];
            generator.script = "environment-file";
          };
        };

        hardware.nvidia-container-toolkit.enable = true;
        virtualisation.podman.enable = true;

        systemd.services.hyperqwen = {
          description = "HyperQwen (patched vLLM) serving Qwen3.8-27B";
          after = [ "nvidia-container-toolkit-cdi-generator.service" ];
          requires = [ "nvidia-container-toolkit-cdi-generator.service" ];
          conflicts = [
            "ninfer.service"
            "llama-cpp.service"
            "ollama.service"
          ];
          wantedBy = lib.optional cfg.autoStart "multi-user.target";
          path = [ config.virtualisation.podman.package ];
          preStart = ''
            mkdir -p ${dir}/cache
            ${seed base "Qwen3.8-27B-W4A16-AutoRound"}
            ${seed dflash2 "Qwen3.8-27B-DFlash2-W4A16"}
          '';
          script = ''
            exec podman run --rm --replace --name hyperqwen \
              --network host --ipc host --device nvidia.com/gpu=all \
              --env-file ${bundle}/env --env-file ${config.age.secrets.hyperqwen-env.path} \
              ${lib.concatStrings (lib.mapAttrsToList (k: v: "-e ${lib.escapeShellArg "${k}=${v}"} ") env)}\
              -v ${dir}/models:/app/models -v ${dir}/cache:/cache \
              -v ${froggeric}:/templates/froggeric.jinja:ro \
              --workdir /app --rootfs ${bundle}/rootfs:O \
              bash docker/entrypoint.sh single
          '';
          # First start requantizes, then compiles CUDA graphs and JITs FlashInfer.
          serviceConfig.TimeoutStartSec = "infinity";
        };

        networking.firewall.extraInputRules = lib.concatMapStrings (ip: ''
          ip saddr ${ip} tcp dport ${toString cfg.port} accept comment "hyperqwen"
        '') cfg.clients;
      };
  };
}
