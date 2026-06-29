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

      argb = alpha: hex: "0x${alpha}${hex}";
      bg = argb "e6" colors.base00;
      surface = argb "ff" colors.base01;
      fg = argb "ff" colors.base05;
      accent = argb "ff" colors.base0D;

      # $NAME / $FOCUSED are injected by sketchybar at runtime (SC2154).
      workspaceScript = lib.getExe (
        pkgs.writeShellApplication {
          name = "sketchybar-workspace";
          runtimeInputs = [
            pkgs.aerospace
            pkgs.sketchybar
          ];
          excludeShellChecks = [ "SC2154" ];
          text = ''
            focused="''${FOCUSED:-$(aerospace list-workspaces --focused)}"
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
          for sid in $(${pkgs.aerospace}/bin/aerospace list-workspaces --all); do
            sketchybar \
              --add item "space.$sid" left \
              --subscribe "space.$sid" aerospace_workspace_changed \
              --set "space.$sid" label="$sid" click_script="${pkgs.aerospace}/bin/aerospace workspace $sid" script="${workspaceScript}"
          done

          sketchybar \
            --add item clock right \
            --set clock update_freq=10 script="${clockScript}" \
            --subscribe clock system_woke

          sketchybar \
            --add item tailscale right \
            --set tailscale update_freq=10 script="${tailscaleScript}"

          sketchybar --update
        '';
      };
    };
}
