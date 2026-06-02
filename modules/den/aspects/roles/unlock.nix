{ den, ... }:
{
  den.aspects.roles.unlock = {
    colmena = [ "unlock" ];
    includes = with den.aspects; [
      core.network.boot
      services.security.tang
    ];
  };
}
