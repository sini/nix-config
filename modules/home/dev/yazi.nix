{ lib, ... }:
{
  flake.modules.homeManager.yazi =
    { config, pkgs, ... }:
    {
      programs = {
        yazi = {
          enable = true;
          enableZshIntegration = true;
          settings = {
            mgr.show_hidden = true;
            open.rules = [
              {
                mime = "*";
                use = "open";
              }
              {
                mime = "inode/directory";
                use = "zsh-dir";
              }
            ];
            opener = {
              open = [
                {
                  run = ''${lib.getExe' pkgs.xdg-utils "xdg-open"} "$@"'';
                  desc = "Open";
                }
              ];
              zsh-dir = [
                {
                  run = ''${lib.getExe config.programs.zsh.package} -c "cd $0 && exec ${lib.getExe config.programs.zsh.package}"'';
                  block = true;
                  desc = "Open directory in zsh";
                }
              ];
            };
          };
        };
      };
    };
}
