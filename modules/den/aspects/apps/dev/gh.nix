{ den, ... }:
{
  den.aspects.gh = den.lib.perUser {
    homeManager = {
      programs.gh = {
        enable = true;
        settings = {
          git_protocol = "ssh";
        };
      };
    };
  };
}
