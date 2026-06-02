_: {
  den.aspects.apps.shell.archive = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.atool
          pkgs.unzip
          pkgs.unrar
          pkgs.cabextract
          pkgs.p7zip
          pkgs.zip
          pkgs.xz
        ];
      };
  };
}
