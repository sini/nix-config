{
  den.aspects.applications.dev.mux.tmux = {
    homeManager = { pkgs, ... }: {
      programs.tmux = {
        enable = true;
        sensibleOnTop = true;
        terminal = "tmux-256color";
        shortcut = "a";
        keyMode = "vi";
        customPaneNavigationAndResize = true;
        baseIndex = 1;
        plugins = with pkgs.tmuxPlugins; [
          extrakto
          cpu
          weather
          battery
          vim-tmux-navigator
          tmux-window-name
        ];
        extraConfig = ''
          set -ga terminal-overrides ",*:Tc"
        '';
      };
    };

    #   homeManager =
    #     {
    #       pkgs,
    #       config,
    #       lib,
    #       ...
    #     }:
    #     let
    #       stylix = config.lib.stylix.colors;
    #       hex = str: "#${str}";

    #       seshFilter = ''--icons | rg -v \"Downloads|config/nixos/.\|~/Documents$|Documents/.*/.*/.*/\"'';
    #       seshCMD = ''
    #         sesh connect \"$(sesh list -d ${seshFilter} | \
    #               fzf-tmux -p 90%,90% \
    #                 --no-sort --layout=reverse --ansi --border-label ' sesh ' --prompt '⚡  ' \
    #                 --header ' ^a all ^t tmux ^g configs ^x tmux kill ^d remove' \
    #                 --bind 'tab:down,btab:up,ctrl-l:accept' \
    #                 --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list ${seshFilter})' \
    #                 --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t -i)' \
    #                 --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c -i)' \
    #                 --bind 'ctrl-x:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list ${seshFilter})' \
    #                 --bind 'ctrl-d:execute(eval zoxide remove {2..})+reload(sesh list ${seshFilter})' \
    #                 --preview-window 'right:55%' \
    #                 --preview 'sesh preview {}'
    #             )\"
    #       '';

    #       tmuxConf = ''
    #         # Status line
    #         set -g status-style "bg=${hex stylix.base00}"
    #         set -g status-left "  #S "

    #         # Window status
    #         set -g window-status-style "bg=${hex stylix.base00},fg=colour8,bold"
    #         set -g window-status-current-style "bg=${hex stylix.base00},bold"

    #         set-window-option -g window-status-current-format "󰊓 #W#{?#{:#{window_bell_flag},#{window_zoomed_flag}},,}#{?window_bell_flag,!,}#{?window_zoomed_flag,Z,}"
    #         set-window-option -g window-status-format "#W#{?#{:#{window_bell_flag},#{window_zoomed_flag}},,}#{?window_bell_flag,!,}#{?window_zoomed_flag,Z,}"

    #         set -g status-position top
    #         set -g renumber-windows on

    #         bind c new-window -c "#{pane_current_path}"
    #         bind '"' split-window -c "#{pane_current_path}"
    #         bind % split-window -h -c "#{pane_current_path}"

    #         set -g status-left-length 65
    #         set -g escape-time 5
    #         set -g status-keys vi
    #         setw -g mode-keys vi
    #         bind -T copy-mode-vi C-v send -X rectangle-toggle
    #         bind-key -T copy-mode-vi 'v' send -X begin-selection
    #         bind-key -T copy-mode-vi 'y' send -X copy-pipe-and-cancel "wl-copy"

    #         bind C-y setw synchronize-panes
    #         set -g status-justify centre
    #         set -g history-limit 10000

    #         set -g default-terminal 'tmux-256color'
    #         set -as terminal-features ',xterm*:RGB'
    #         set set-clipboard on
    #         set -gw xterm-keys on
    #         set -s extended-keys on

    #         set -gu prefix2
    #         unbind C-a
    #         unbind C-b
    #         set -g prefix C-s
    #         bind -T prefix C-s send-keys C-s
    #         set-option -g allow-rename off
    #         set -g allow-passthrough on
    #         set -g update-environment TERM
    #         set -g update-environment TERM_PROGRAM

    #         set -s extended-keys on

    #         bind-key -n C-Enter split-window -h -c "#{pane_current_path}"
    #         bind-key -n C-q killp
    #         unbind '"'
    #         unbind %
    #         unbind -n C-i

    #         bind-key -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe-and-cancel "wl-copy"

    #         bind c choose-window "kill-window -t %%"
    #         bind r command-prompt "rename-session '%%'"
    #         bind n new-window -c "#{pane_current_path}"

    #         bind C-f display-popup -E -h 80% -w 80% "\
    #         tmux list-window -F '#{window_name} #{pane_id}' |\
    #         fzf -d' ' --prompt 'FOCUS window ' --preview 'tmux capture-pane -ept {-1} | bat' --reverse |\
    #         cut -d' ' -f2 | xargs tmux select-window -t"

    #         bind f run "cut -c3- '#{TMUX_CONF}' | sh -s _maximize_pane '#{session_name}' '#D'"
    #         bind-key -n M-1 select-window -t:1
    #         bind-key -n M-2 select-window -t:2
    #         bind-key -n M-3 select-window -t:3
    #         bind-key -n M-4 select-window -t:4
    #         bind-key -n M-5 select-window -t:5
    #         bind-key -n M-6 select-window -t:6
    #         bind-key -n M-7 select-window -t:7
    #         bind-key -n C-S-^ last-window
    #         bind-key -n M-S-1 swap-window -s 1
    #         bind-key -n M-S-2 swap-window -s 2
    #         bind-key -n M-S-3 swap-window -s 3
    #         bind-key -n M-S-4 swap-window -s 4
    #         bind-key -n M-S-5 swap-window -s 5
    #         bind-key -n M-S-6 swap-window -s 6
    #         bind-key -n M-S-7 swap-window -s 7
    #         bind-key -n M-S-8 swap-window -s 8
    #         bind-key -n M-S-9 swap-window -s 9

    #         set -g status-position top

    #         unbind -n M-j
    #         unbind -n M-k

    #         unbind -n C-space
    #         bind-key -n M-[ next-layout
    #         bind-key -n M-] previous-layout

    #         bind-key -n M-WheelUpStatus previous-window
    #         bind-key -n M-WheelUpPane previous-window

    #         bind-key -n M-WheelDownStatus next-window
    #         bind-key -n M-WheelDownPane next-window

    #         bind-key -r -n   C-S-K   resize-pane -U 8
    #         bind-key -r -n   C-S-J   resize-pane -D 8
    #         bind-key -r -n   C-S-H   resize-pane -L 8
    #         bind-key -r -n   C-S-L   resize-pane -R 8

    #         is_vim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?(g?\.?(view|n?vim?x?)(-wrapped)?(diff)?|fzf|atuin)$'"

    #         bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h' { if -F '#{pane_at_left}' ''' 'select-pane -L' }
    #         bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j' { if -F '#{pane_at_bottom}' ''' 'select-pane -D' }
    #         bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k' { if -F '#{pane_at_top}' ''' 'select-pane -U' }
    #         bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l' { if -F '#{pane_at_right}' ''' 'select-pane -R' }

    #         bind-key -r -n   C-S-k   resize-pane -U 8
    #         bind-key -r -n   C-S-j   resize-pane -D 8
    #         bind-key -r -n   C-S-h   resize-pane -L 8
    #         bind-key -r -n   C-S-l   resize-pane -R 8

    #         bind-key -T copy-mode-vi 'C-h' if -F '#{pane_at_left}' ''' 'select-pane -L'
    #         bind-key -T copy-mode-vi 'C-j' if -F '#{pane_at_bottom}' ''' 'select-pane -D'
    #         bind-key -T copy-mode-vi 'C-k' if -F '#{pane_at_top}' ''' 'select-pane -U'
    #         bind-key -T copy-mode-vi 'C-l' if -F '#{pane_at_right}' ''' 'select-pane -R'

    #         bind-key -n "C-S-n" run-shell "${seshCMD}"
    #         bind s run-shell "${seshCMD}"
    #         bind -N "last-session (via sesh) " L run-shell "sesh last"
    #         bind -N "switch to root session (via sesh) " C-r run-shell "sesh connect --root \'$(pwd)\' || true"
    #       '';
    #     in
    #     {
    #       programs.tmux = {
    #         enable = true;
    #         prefix = "C-s";
    #         sensibleOnTop = true;
    #         shell = "${pkgs.zsh}/bin/zsh";
    #         terminal = "tmux-256color";
    #         mouse = true;
    #         baseIndex = 1;
    #         plugins = with pkgs; [
    #           {
    #             plugin = pkgs.tmuxPlugins.mkTmuxPlugin {
    #               pluginName = "tmux-fzf-links";
    #               version = "unstable-2025-01-01";
    #               rtpFilePath = "fzf-links.tmux";
    #               src = fetchFromGitHub {
    #                 owner = "alberti42";
    #                 repo = "tmux-fzf-links";
    #                 rev = "8eec1c11988c2a09dc647ff40cfcc882dda84d73";
    #                 hash = "sha256-YBiu0CHkLDfdNogHQLHEiAweNnEzwRqwFWW3lLB9tpw=";
    #               };
    #             };
    #             extraConfig = ''
    #               set-option -g @fzf-links-python "${lib.getExe pkgs.python314}"
    #               set-option -g @fzf-links-fzf-display-options "-w 70% --maxnum-displayed 20 --multi --track --no-preview"
    #               set-option -g @fzf-links-key o
    #             '';
    #           }
    #           {
    #             plugin = tmuxPlugins.tmux-floax;
    #             extraConfig = ''
    #               set -g @floax-bind '-n C-\'
    #               set -g @floax-change-path 'false'
    #             '';
    #           }
    #           {
    #             plugin = tmuxPlugins.mode-indicator;
    #             extraConfig = ''
    #               set -g @mode_indicator_prefix_prompt ' WAIT '
    #               set -g @mode_indicator_copy_prompt ' COPY '
    #               set -g @mode_indicator_sync_prompt ' SYNC '
    #               set -g @mode_indicator_empty_prompt ' TMUX '
    #               set -g @mode_indicator_prefix_mode_style 'fg=${hex stylix.base0D},bg=${hex stylix.base01}'
    #               set -g @mode_indicator_copy_mode_style 'fg=${hex stylix.base0A},bg=${hex stylix.base01}'
    #               set -g @mode_indicator_sync_mode_style 'fg=${hex stylix.base08},bg=${hex stylix.base01}'
    #               set -g @mode_indicator_empty_mode_style 'fg=${hex stylix.base0C},bg=${hex stylix.base01}'
    #               set -g status-right " #{tmux_mode_indicator}"
    #             '';
    #           }
    #         ];
    #         extraConfig = tmuxConf;
    #       };
    #     };
  };
}
