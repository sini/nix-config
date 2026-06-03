{ den, ... }:
{
  den.aspects.roles.unlock = {
    includes = with den.aspects; [
      core.boot.network-initrd
      services.security.tang
    ];
  };
}
