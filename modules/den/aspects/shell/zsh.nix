{ den, lib, ... }:
{
  den.aspects.shell = {
    # All sub-aspects are included when the generic 'shell' aspect is used
    includes = lib.attrValues den.aspects.shell._;

    _.zsh = {
      # Bundles all zsh components when the complete 'zsh' sub-aspect is used
      includes = lib.attrValues den.aspects.shell._.zsh._;

      _ = {
        # Enable zsh system-wide and set it as the default shell on NixOS
        systemEnable = den.lib.perHost {
          os = {
            programs.zsh = {
              enable = true;
              enableCompletion = true;
            };
          };

          nixos =
            { pkgs, ... }:
            {
              users.defaultUserShell = pkgs.zsh;
            };
        };

        # Home-manager zsh configuration (shared across platforms)
        config = den.lib.perUser {
          homeManager =
            {
              config,
              lib,
              pkgs,
              ...
            }:
            {
              home = {
                packages = with pkgs; [
                  sqlite-interactive # For zsh-histdb
                  nix-zsh-completions
                  fzy
                  libnotify
                ];

                persistence."/persist".directories = [
                  ".local/share/zsh" # History
                ];

                # Works around logic that prevents reloading env vars
                sessionVariablesExtra = ''
                  unset __HM_SESS_VARS_SOURCED
                  unset __HM_ZSH_SESS_VARS_SOURCED
                '';
              };

              programs.zsh = {
                enable = lib.mkDefault true;
                dotDir = lib.mkDefault "${config.xdg.configHome}/zsh";
                autosuggestion.enable = lib.mkDefault true;
                enableCompletion = lib.mkDefault true;
                completionInit = lib.mkDefault "autoload -U compinit && compinit -i";
                defaultKeymap = lib.mkDefault "emacs";
                autocd = lib.mkDefault true;
                history = {
                  path = lib.mkDefault "\${XDG_DATA_HOME-$HOME/.local/share}/zsh/history";
                  ignoreSpace = lib.mkDefault true;
                  size = lib.mkDefault 1000000;
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
                };

                syntaxHighlighting = {
                  enable = lib.mkDefault true;
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
                  "ssh-kitty" = "kitty +kitten ssh";
                  "ssh-ignore" =
                    "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null";
                  "fixstore" = "sudo nix-store --verify --check-contents --repair";
                  "flake-update" = "nix flake update --option access-tokens \"github.com=$(gh auth token)\"";
                };
              };
            };
        };

        # Linux-only locale archive env vars (glibc is Linux-only)
        # https://github.com/NixOS/nixpkgs/issues/38991
        linuxLocale = den.lib.perUser {
          homeLinux =
            { pkgs, ... }:
            {
              programs.zsh.sessionVariables = {
                "LOCALE_ARCHIVE_2_11" = "${pkgs.glibcLocales}/lib/locale/locale-archive";
                "LOCALE_ARCHIVE_2_27" = "${pkgs.glibcLocales}/lib/locale/locale-archive";
              };
            };
        };
      };
    };
  };
}
