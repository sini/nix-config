# time — timezone from environment entity.
#
# Ported from main:modules/_legacy/core/time.nix.
{ den, lib, config, ... }:
let
  environments = config.den.environments;
in
{
  den.aspects.core.time = {
    nixos =
      { host, ... }:
      let
        env = environments.${host.environment};
      in
      {
        time.timeZone = env.timezone or "UTC";
      };
  };
}
