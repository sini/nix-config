{ den, ... }:
{
  den.aspects.roles.unlock = {
    includes = with den.aspects; [
      network.network-boot
      services.tang
    ];
  };
}
