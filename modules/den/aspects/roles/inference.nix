{ den, ... }:
{
  den.aspects.roles.inference = {
    includes = with den.aspects; [
      # services.ai.ollama
      services.ai.llama-cpp
      # Installed alongside llama-cpp but not started at boot: the two conflict
      # over the single GPU (see services.ai.ninfer `autoStart`).
      services.ai.ninfer
    ];
  };
}
