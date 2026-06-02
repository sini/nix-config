{
  den.aspects.apps.dev.lang.python = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.python3
        ];
      };
  };
}
