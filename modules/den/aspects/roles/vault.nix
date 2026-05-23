{ den, ... }:
{
  den.aspects.roles.vault = {
    includes = [ den.aspects.services.vault ];
  };
}
