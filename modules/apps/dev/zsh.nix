{
  flake.modules = {
    nixos.zsh =
      { pkgs, ... }:
      {
        programs.zsh = {
          enable = true;
          enableCompletion = true;
        };

        users.defaultUserShell = pkgs.zsh;
      };

    homeManager.zsh =
      {
        pkgs,
        lib,
        ...
      }:
      {
        home.packages = with pkgs; [
          sqlite-interactive # For zsh-histdb
          nix-zsh-completions
          fzy
          libnotify
        ];

        # home.persistence."/persist".directories = [
        #   ".local/share/zsh" # History
        # ];

        programs.zsh = {
          enable = true;
          dotDir = ".config/zsh";
          autosuggestion.enable = true;
          enableCompletion = true;
          completionInit = "autoload -U compinit && compinit -i";
          autocd = true;
          history = {
            path = "\${XDG_DATA_HOME-$HOME/.local/share}/zsh/history";
            ignoreSpace = true;
            size = 1000000;
          };
          plugins = [
            {
              # Must be before plugins that wrap widgets, such as zsh-autosuggestions or fast-syntax-highlighting
              name = "fzf-tab";
              src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
            }
            {
              name = "auto-notify";
              src = "${pkgs.local.zsh-auto-notify}/share/zsh-auto-notify/zsh-auto-notify.plugin.zsh";
            }
            {
              name = "fast-syntax-highlighting";
              src = "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions";
            }
            {
              name = "zsh-autosuggestions";
              file = "zsh-autosuggestions.zsh";
              src = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
            }
            {
              name = "zsh-histdb";
              src = "${pkgs.local.zsh-histdb}/share/zsh-histdb";
            }
            {
              name = "zsh-skim-histdb";
              src = "${pkgs.local.zsh-skim-histdb}/share/zsh-skim-histdb";
            }
          ];

          sessionVariables = {
            "DIRSTACKSIZE" = "20";
            "NIX_BUILD_SHELL" = "zsh";
            # Set locale archives
            # https://github.com/NixOS/nixpkgs/issues/38991
            "LOCALE_ARCHIVE_2_11" = "${pkgs.glibcLocales}/lib/locale/locale-archive";
            "LOCALE_ARCHIVE_2_27" = "${pkgs.glibcLocales}/lib/locale/locale-archive";
          };

          syntaxHighlighting = {
            enable = true;
            highlighters = [
              "main"
              "brackets"
              "pattern"
              "regexp"
              "cursor"
              "line"
            ];
          };

          initContent = lib.mkMerge [
            (lib.mkBefore ''
              HISTDB_FILE=''${XDG_DATA_HOME-$HOME/.local/share}/zsh/history.db

              # Do this early so fast-syntax-highlighting can wrap and override this
              if autoload history-search-end; then
                zle -N history-beginning-search-backward-end history-search-end
                zle -N history-beginning-search-forward-end  history-search-end
              fi
            '')
          ];

          shellAliases = {
            ".." = "cd ..";
            "..." = "cd ../..";
            "rm" = "rm -i";
            "j" = "journalctl -xe";
            "e" = "emacsclient -n";
            "start" = "systemctl --user start";
            "stop" = "systemctl --user stop";
            "enable" = "systemctl --user enable";
            "disable" = "systemctl --user disable";
            "reload" = "systemctl --user daemon-reload";
            "status" = "systemctl --user --full status";
            "restart" = "systemctl --user restart";
            "ssh-ignore" = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null";
            "fixstore" = "sudo nix-store --verify --check-contents --repair";
          };
        };
      };
  };
}
