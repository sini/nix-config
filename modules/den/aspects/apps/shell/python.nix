{ den, ... }:
{
  den.aspects.python = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          python3
        ];
      };
  };
}
