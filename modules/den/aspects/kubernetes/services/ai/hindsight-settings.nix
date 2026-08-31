# Settings for the hindsight aspect. Surfaced onto the cluster as
# `cluster.settings.kubernetes.services.ai.hindsight.*`; set per cluster via
# `den.clusters.<name>.settings.kubernetes.services.ai.hindsight.<key>`.
#
# Both point at llama-cpp instances by KEY rather than by URL or model name, so
# the model identity lives in exactly one place — the llama-cpp aspect's
# `instances` — and changing a model there carries here without edits. The
# service address and the `model` string clients must send are both derived.
{ lib, ... }:
{
  # Everything except retain: reflect, consolidation, verification. gpt-oss-20b
  # is rank 2 of 21 on upstream's reflect leaderboard (86.3 against the leader's
  # 86.6, and the leader is gpt-oss-120b which will not fit here). No Qwen model
  # appears on that board at all.
  den.aspects.kubernetes.services.ai.hindsight.settings.defaultLlmInstance = lib.mkOption {
    type = lib.types.str;
    default = "gpt-oss";
    description = ''
      Key into `kubernetes.services.ai.llama-cpp.instances` serving the default
      LLM for every operation without its own override.
    '';
  };

  # Retain is the write path, and it gets the better extractor: Qwen3.6 35B-A3B
  # leads the open-weight field on the retain leaderboard at quality 59.5 (49%)
  # against 56.3 (48%) for both gpt-oss 20B and the dense Qwen3.8 27B. Measured
  # on this hardware it decodes at 23.2 tok/s against gpt-oss's 28.9 — a fifth
  # slower for a 3.2-point quality gain, on a path that is asynchronous anyway.
  den.aspects.kubernetes.services.ai.hindsight.settings.retainLlmInstance = lib.mkOption {
    type = lib.types.str;
    default = "qwen";
    description = ''
      Key into `kubernetes.services.ai.llama-cpp.instances` serving the retain
      (fact-extraction) path, via HINDSIGHT_API_RETAIN_LLM_*.
    '';
  };
}
