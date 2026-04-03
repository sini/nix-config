{ den, ... }:
{
  den.aspects.hosts-file = den.lib.perHost {
    nixos = { }; # Stub - cross-host discovery deferred to environment context
  };
}
