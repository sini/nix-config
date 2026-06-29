# AeroSpace tiling window manager. Alt-based bindings (no karabiner dependency),
# 9 workspaces, and a hook that notifies sketchybar on workspace changes.
{ lib, ... }:
{
  den.aspects.macos.wm.aerospace.homeDarwin =
    { pkgs, ... }:
    let
      workspaces = map toString (lib.range 1 9);
      gap = 8;
      toWorkspace = lib.listToAttrs (map (n: lib.nameValuePair "alt-${n}" "workspace ${n}") workspaces);
      moveToWorkspace = lib.listToAttrs (
        map (n: lib.nameValuePair "alt-shift-${n}" "move-node-to-workspace ${n}") workspaces
      );
    in
    {
      programs.aerospace = {
        enable = true;
        launchd.enable = true;
        settings = {
          start-at-login = true;
          enable-normalization-flatten-containers = true;
          enable-normalization-opposite-orientation-for-nested-containers = true;
          accordion-padding = gap * 2;
          default-root-container-layout = "tiles";
          default-root-container-orientation = "auto";
          automatically-unhide-macos-hidden-apps = true;
          on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

          gaps = {
            inner.horizontal = gap;
            inner.vertical = gap;
            outer.left = gap;
            outer.right = gap;
            outer.top = gap;
            outer.bottom = gap;
          };

          # Keep sketchybar's workspace indicators in sync.
          exec-on-workspace-change = [
            "/bin/bash"
            "-c"
            "${pkgs.sketchybar}/bin/sketchybar --trigger aerospace_workspace_changed FOCUSED=$AEROSPACE_FOCUSED_WORKSPACE"
          ];

          mode.main.binding = {
            # Layout
            alt-slash = "layout tiles horizontal vertical";
            alt-comma = "layout accordion horizontal vertical";
            # Focus
            alt-h = "focus left";
            alt-j = "focus down";
            alt-k = "focus up";
            alt-l = "focus right";
            # Move
            alt-shift-h = "move left";
            alt-shift-j = "move down";
            alt-shift-k = "move up";
            alt-shift-l = "move right";
            # Size
            alt-minus = "resize smart -50";
            alt-equal = "resize smart +50";
            # Fullscreen
            alt-f = "fullscreen";
          }
          // toWorkspace
          // moveToWorkspace;
        };
      };
    };
}
