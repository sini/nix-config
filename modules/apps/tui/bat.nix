{ lib, ... }:
{
  flake.modules.homeManager.bat =
    { pkgs, ... }:
    {
      programs.bat = {
        enable = true;
        # config = {
        #   pager = "less -FR";
        # };
        extraPackages = with pkgs.bat-extras; [
          batman
          batpipe
          batgrep
        ];
      };
      home.shellAliases = {
        cat = "${lib.getExe pkgs.bat} --color=always --style=plain --paging=never";
      };
    };
}
