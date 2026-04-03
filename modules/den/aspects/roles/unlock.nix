# Unlock role: includes tang for disk unlock.
{ den, ... }:
{
  den.aspects.unlock = {
    includes = [
      den.aspects.tang
    ];
  };
}
