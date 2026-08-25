{ den, ... }:
{
  den.aspects.roles.inference = {
    includes = with den.aspects; [
      # services.ai.ollama
      services.ai.llama-cpp
    ];
  };
}
