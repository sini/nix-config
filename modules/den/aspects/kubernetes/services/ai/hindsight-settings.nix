# Settings for the hindsight aspect. Surfaced onto the cluster as
# `cluster.settings.kubernetes.services.ai.hindsight.*`; set per cluster via
# `den.clusters.<name>.settings.kubernetes.services.ai.hindsight.<key>`.
{ lib, ... }:
{
  # The model that performs fact extraction on the retain (write) path. Recall
  # needs no LLM at all, and retain runs async in the background, so throughput
  # is not latency-critical — upstream's own guidance is that "Hindsight doesn't
  # need a smart model" and recommends the gpt-oss-20b class. The tag must be
  # one the target ollama host has actually pulled; an absent model fails the
  # retain, it does not degrade.
  den.aspects.kubernetes.services.ai.hindsight.settings.extractionModel = lib.mkOption {
    type = lib.types.str;
    default = "gpt-oss:20b";
    description = ''
      Ollama model tag used for retain-path fact extraction
      (HINDSIGHT_API_LLM_MODEL). Must be pulled on the host serving
      extractionBaseUrl.
    '';
  };

  # Default null → derive from the ollama-endpoints quirk, so the endpoint
  # follows the fleet rather than being restated here. Set this only to point
  # extraction somewhere the quirk does not describe (a ninfer/llama.cpp
  # endpoint, say) — and note that doing so also needs the egress
  # CiliumNetworkPolicy in hindsight.nix widened to reach it.
  den.aspects.kubernetes.services.ai.hindsight.settings.extractionBaseUrl = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      OpenAI-compatible base URL for the extraction LLM
      (HINDSIGHT_API_LLM_BASE_URL). null derives it from the ollama-endpoints
      quirk (the fleet's ollama hosts in this environment).
    '';
  };
}
