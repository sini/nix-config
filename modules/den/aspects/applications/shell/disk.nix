{
  den.aspects.applications.shell.disk = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.dust
          pkgs.dua
          pkgs.dysk
          pkgs.ncdu
        ];
      };
  };
}
