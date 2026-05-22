{ den, ... }:
{
  den.aspects.roles.inference = {
    includes = with den.aspects; [
      services.ollama
    ];
  };
}
