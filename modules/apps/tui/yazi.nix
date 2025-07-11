{ lib, ... }:
{
  flake.modules.homeManager.yazi =
    { config, pkgs, ... }:
    {
      programs = {
        yazi = {
          enable = true;
          enableZshIntegration = true;
          plugins = lib.genAttrs [
            "toggle-pane"
            "chmod"
            "full-border"
            "no-status"
            "starship"
            "ouch"
            "relative-motions"
          ] (name: pkgs.yaziPlugins.${name});
          settings = {
            mgr.show_hidden = true;
            open.rules = [
              {
                mime = "inode/directory";
                use = "zsh-dir";
              }
              {
                mime = "*";
                use = "open";
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
