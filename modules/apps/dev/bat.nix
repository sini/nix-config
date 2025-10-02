{ lib, ... }:
{
  flake.features.bat.home =
    { pkgs, ... }:
    {
      programs.bat = {
        enable = true;
        config.style = "plain";
        extraPackages = with pkgs.bat-extras; [
          prettybat
          batwatch
          batpipe
          batman
          batgrep
          batdiff
        ];
      };
      home.shellAliases = {
        cat = "${lib.getExe pkgs.bat} --color=always --style=plain --paging=never";
      };
    };
}
