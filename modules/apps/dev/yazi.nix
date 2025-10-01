{ lib, ... }:
{
  flake.aspects.yazi.home =
    { config, pkgs, ... }:
    {
      programs = {
        yazi = {
          enable = true;
          enableBashIntegration = true;
          enableNushellIntegration = true;
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
            manager = {
              linemode = "mtime";
              show_hidden = true;
              show_symlink = true;
              sort_by = "natural";
              sort_dir_first = true;
              sort_reverse = false;
              sort_sensitive = false;
            };
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
