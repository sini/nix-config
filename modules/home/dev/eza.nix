{ lib, ... }:
{
  flake.modules.homeManager.eza =
    { pkgs, ... }:
    let
      l = lib.concatStringsSep " " [
        "${lib.getExe pkgs.eza}"
        "--group"
        "--icons"
        "--git"
        "--header"
        "--all"
      ];
    in
    {
      programs.eza.enable = true;
      home.shellAliases = {
        inherit l;
        ll = "${l} --long";
        lt = "${l} --tree";
      };
    };
}
