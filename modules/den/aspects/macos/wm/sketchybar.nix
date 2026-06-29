# SketchyBar status bar: aerospace workspace indicators on the left, clock and
# tailscale status on the right. Themed from the stylix base16 palette and the
# stylix monospace (Nerd) font so it matches the rest of the fleet.
{ lib, ... }:
{
  den.aspects.macos.wm.sketchybar.homeDarwin =
    { config, pkgs, ... }:
    let
      inherit (config.lib.stylix) colors;
      font = config.stylix.fonts.monospace.name;

      # Fixed workspace set, matching the aerospace bindings (alt-1..9). Generated
      # statically rather than by querying `aerospace list-workspaces` at config
      # load: sketchybar's launch agent can start before AeroSpace is ready, so a
      # load-time query races and silently drops the workspace items.
      workspaces = map toString (lib.range 1 9);

      argb = alpha: hex: "0x${alpha}${hex}";
      bg = argb "e6" colors.base00;
      surface = argb "ff" colors.base01;
      fg = argb "ff" colors.base05;
      accent = argb "ff" colors.base0D;

      # $NAME / $FOCUSED are injected by sketchybar at runtime (SC2154). The
      # aerospace query is guarded so a not-yet-ready server doesn't abort the
      # script (writeShellApplication runs under `set -euo pipefail`).
      workspaceScript = lib.getExe (
        pkgs.writeShellApplication {
          name = "sketchybar-workspace";
          runtimeInputs = [
            pkgs.aerospace
            pkgs.sketchybar
          ];
          excludeShellChecks = [ "SC2154" ];
          text = ''
            focused="''${FOCUSED:-}"
            if [ -z "$focused" ]; then
              focused="$(aerospace list-workspaces --focused 2>/dev/null || true)"
            fi
            sid="''${NAME#space.}"
            if [ "$sid" = "$focused" ]; then
              sketchybar --set "$NAME" background.drawing=on background.color=${accent} label.color=${bg}
            else
              sketchybar --set "$NAME" background.drawing=off label.color=${fg}
            fi
          '';
        }
      );

      clockScript = lib.getExe (
        pkgs.writeShellApplication {
          name = "sketchybar-clock";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.sketchybar
          ];
          excludeShellChecks = [ "SC2154" ];
          text = ''sketchybar --set "$NAME" label="$(date '+%a %d %b  %H:%M')"'';
        }
      );

      tailscaleScript = lib.getExe (
        pkgs.writeShellApplication {
          name = "sketchybar-tailscale";
          runtimeInputs = [
            pkgs.tailscale
            pkgs.sketchybar
          ];
          excludeShellChecks = [ "SC2154" ];
          text = ''
            if tailscale status >/dev/null 2>&1; then
              sketchybar --set "$NAME" label="tailnet" label.color=${accent}
            else
              sketchybar --set "$NAME" label="offline" label.color=${fg}
            fi
          '';
        }
      );

      workspaceItems = lib.concatMapStringsSep "\n" (sid: ''
        sketchybar \
          --add item space.${sid} left \
          --subscribe space.${sid} aerospace_workspace_changed \
          --set space.${sid} label="${sid}" click_script="${pkgs.aerospace}/bin/aerospace workspace ${sid}" script="${workspaceScript}"
      '') workspaces;
    in
    {
      programs.sketchybar = {
        enable = true;
        service.enable = true;
        extraPackages = with pkgs; [
          aerospace
          coreutils
          tailscale
        ];
        config.text = ''
          sketchybar --bar \
            position=top \
            height=36 \
            blur_radius=20 \
            color=${bg} \
            padding_left=8 \
            padding_right=8

          sketchybar --default \
            icon.font="${font}:Bold:14.0" \
            icon.color=${fg} \
            label.font="${font}:Bold:13.0" \
            label.color=${fg} \
            background.color=${surface} \
            background.corner_radius=6 \
            background.height=24 \
            padding_left=4 \
            padding_right=4

          sketchybar --add event aerospace_workspace_changed
          ${workspaceItems}

          sketchybar \
            --add item clock right \
            --set clock update_freq=10 script="${clockScript}" \
            --subscribe clock system_woke

          sketchybar \
            --add item tailscale right \
            --set tailscale update_freq=10 script="${tailscaleScript}"

          # Paint the current workspace highlight now that all items exist (and
          # again whenever aerospace reports a change).
          sketchybar --update
          sketchybar --trigger aerospace_workspace_changed
        '';
      };

      # home-manager doesn't restart the launchd agent when only the (fixed-path)
      # sketchybarrc content changes, so kickstart it on activation to load the
      # new config.
      home.activation.restartSketchybar = config.lib.dag.entryAfter [ "setupLaunchAgents" ] ''
        run /bin/launchctl kickstart -k "gui/$UID/org.nix-community.home.sketchybar" || true
      '';
    };
}
