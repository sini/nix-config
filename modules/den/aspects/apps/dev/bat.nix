{ den, lib, ... }:
{
  den.aspects.apps.bat = {
    homeManager =
      { pkgs, ... }:
      {
        programs.bat = {
          enable = true;
          config.style = "plain";
          extraPackages = [
            pkgs.bat-extras.prettybat
            pkgs.bat-extras.batwatch
            pkgs.bat-extras.batpipe
            pkgs.bat-extras.batman
            pkgs.bat-extras.batgrep
            pkgs.bat-extras.batdiff
          ];
        };
        home.shellAliases = {
          cat = "${lib.getExe pkgs.bat} -pp";
        };
      };
  };
}
