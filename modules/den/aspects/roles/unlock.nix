{ den, ... }:
{
  den.aspects.roles.unlock = {
    colmena = [ "unlock" ];
    includes = with den.aspects; [
      network.network-boot
      services.tang
    ];
  };
}
