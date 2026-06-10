{
  den.aspects.apps.wayland.hyprland-split-monitors = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.split-monitor-workspaces
        ];

        wayland.windowManager.hyprland = {
          plugins = [
            pkgs.split-monitor-workspaces
          ];

          settings = {
            plugin = {
              split-monitor-workspaces = {
                count = 5;
                keep_focused = false;
                enable_notifications = false;
                enable_persistent_workspaces = 1;
                enable_wrapping = false;
              };
            };

            bind =
              let
                PRIMARY = "SUPER";
                SECONDARY = "SHIFT";
                TERTIARY = "CTRL";
              in
              [
                "${PRIMARY}, page_up, split-workspace, m-1"
                "${PRIMARY}, page_down, split-workspace, m+1"
                "${PRIMARY}, bracketleft, split-workspace, -1"
                "${PRIMARY}, bracketright, split-workspace, +1"
                "${PRIMARY}, mouse_up, split-workspace, m+1"
                "${PRIMARY}, mouse_down, split-workspace, m-1"
                "${PRIMARY} ${SECONDARY}, U, movetoworkspace, special"
                "${PRIMARY}, U, togglespecialworkspace,"
                "${PRIMARY} ${TERTIARY}, page_up, split-movetoworkspace, -1"
                "${PRIMARY} ${TERTIARY}, page_down, split-movetoworkspace, +1"
                "${PRIMARY} ${SECONDARY}, page_up, split-movetoworkspacesilent, -1"
                "${PRIMARY} ${SECONDARY}, page_down, split-movetoworkspacesilent, +1"

                "${PRIMARY} ${TERTIARY}, left, split-changemonitor, prev"
                "${PRIMARY} ${TERTIARY}, right, split-changemonitor, next"
              ]
              ++ (builtins.concatLists (
                builtins.genList (
                  x:
                  let
                    ws = toString (x + 1);
                  in
                  [
                    "${PRIMARY}, ${ws}, split-workspace, ${toString (x + 1)}"
                    "${PRIMARY} ${TERTIARY}, ${ws}, split-movetoworkspace, ${toString (x + 1)}"
                    "${PRIMARY} ${SECONDARY}, ${ws}, split-movetoworkspacesilent, ${toString (x + 1)}"
                  ]
                ) 5
              ));
          };
        };
      };
  };
}
