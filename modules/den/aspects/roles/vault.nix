{ den, ... }:
{
  den.aspects.roles.vault = {
    colmena = [ "vault" ];
    includes = [ den.aspects.services.security.vault ];
  };
}
