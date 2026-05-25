{ den, ... }:
{
  den.aspects.roles.unlock = {
    colmena-tags = [ "unlock" ];
    includes = with den.aspects; [
      network.network-boot
      services.tang
    ];
  };
}
