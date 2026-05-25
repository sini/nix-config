{ den, ... }:
{
  den.aspects.roles.vault = {
    colmena-tags = [ "vault" ];
    includes = [ den.aspects.services.vault ];
  };
}
