{ den, ... }:
{
  den.aspects.roles.inference = {
    colmena-tags = [ "inference" ];
    includes = with den.aspects; [
      services.ollama
    ];
  };
}
