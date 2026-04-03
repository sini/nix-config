{ den, ... }:
{
  den.aspects.delta = den.lib.perUser {
    homeManager = {
      programs.delta = {
        enable = true;
        options = {
          light = false;
          line-numbers = true;
          navigate = true;
          side-by-side = true;
        };
      };
    };
  };
}
