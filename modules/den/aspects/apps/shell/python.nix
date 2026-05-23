_: {
  den.aspects.apps.python = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.python3
        ];
      };
  };
}
