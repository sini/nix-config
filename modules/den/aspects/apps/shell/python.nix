_: {
  den.aspects.apps.shell.python = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.python3
        ];
      };
  };
}
