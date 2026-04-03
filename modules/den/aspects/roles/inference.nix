# Inference role: includes ollama for local LLM inference.
{ den, ... }:
{
  den.aspects.inference = {
    includes = [
      den.aspects.ollama
    ];
  };
}
