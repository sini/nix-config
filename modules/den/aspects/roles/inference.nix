{ den, ... }:
{
  den.aspects.roles.inference = {
    colmena = [ "inference" ];
    includes = with den.aspects; [
      services.ai.ollama
    ];
  };
}
