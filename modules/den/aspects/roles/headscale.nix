# Headscale role: includes headscale service.
{ den, ... }:
{
  den.aspects.headscale-role = {
    includes = [
      den.aspects.headscale
    ];
  };
}
