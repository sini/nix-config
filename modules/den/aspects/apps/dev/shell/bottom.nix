{
  den.aspects.apps.shell.bottom = {
    homeManager =
      { pkgs, ... }:
      {
        programs.bottom = {
          enable = true;
          package = pkgs.bottom;
          settings = { };
        };
      };
  };
}
