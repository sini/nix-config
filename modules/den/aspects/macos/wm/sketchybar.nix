# SketchyBar: a floating "islands" status bar themed from the stylix base16
# palette and the stylix monospace (Nerd) font. The bar itself is transparent
# (no full-width blurred strip) — each item/group carries its own pill.
# Left: aerospace workspace pills + focused app. Right: volume, battery, clock,
# tailscale grouped in one pill.
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

      # "rrggbb" (stylix) -> 0xAARRGGBB (sketchybar).
      argb = alpha: hex: "0x${alpha}${hex}";
      bg = argb "ff" colors.base00; # solid, for text on accent
      surface = argb "f2" colors.base01; # pill background (no bar blur, so near-opaque)
      fg = argb "ff" colors.base05;
      muted = argb "ff" colors.base04;
      accent = argb "ff" colors.base0D; # blue
      green = argb "ff" colors.base0B;
      red = argb "ff" colors.base08;

      # $NAME / $FOCUSED / $INFO are injected by sketchybar at runtime (SC2154).
      mkScript =
        {
          name,
          runtimeInputs ? [ ],
          text,
        }:
        lib.getExe (
          pkgs.writeShellApplication {
            inherit name text;
            runtimeInputs = runtimeInputs ++ [ pkgs.sketchybar ];
            excludeShellChecks = [ "SC2154" ];
          }
        );

      # The aerospace query is guarded so a not-yet-ready server can't abort the
      # script (writeShellApplication runs under `set -euo pipefail`).
      workspaceScript = mkScript {
        name = "sketchybar-workspace";
        runtimeInputs = [ pkgs.aerospace ];
        text = ''
          focused="''${FOCUSED:-}"
          if [ -z "$focused" ]; then
            focused="$(aerospace list-workspaces --focused 2>/dev/null || true)"
          fi
          sid="''${NAME#space.}"
          if [ "$sid" = "$focused" ]; then
            sketchybar --set "$NAME" background.color=${accent} icon.color=${bg}
          else
            sketchybar --set "$NAME" background.color=${surface} icon.color=${muted}
          fi
        '';
      };

      frontAppScript = mkScript {
        name = "sketchybar-front-app";
        text = ''sketchybar --set "$NAME" label="''${INFO:-}"'';
      };

      clockScript = mkScript {
        name = "sketchybar-clock";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''sketchybar --set "$NAME" label="$(date '+%a %d %b  %H:%M')"'';
      };

      volumeScript = mkScript {
        name = "sketchybar-volume";
        text = ''
          vol="''${INFO:-0}"
          case "$vol" in (*[!0-9]*) vol=0 ;; esac
          if [ "$vol" -eq 0 ]; then
            icon="󰖁"
          elif [ "$vol" -lt 34 ]; then
            icon="󰕿"
          elif [ "$vol" -lt 67 ]; then
            icon="󰖀"
          else
            icon="󰕾"
          fi
          sketchybar --set "$NAME" icon="$icon" label="''${vol}%"
        '';
      };

      batteryScript = mkScript {
        name = "sketchybar-battery";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        text = ''
          batt="$(/usr/bin/pmset -g batt)"
          pct="$(echo "$batt" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"
          [ -z "$pct" ] && pct=0
          if echo "$batt" | grep -q 'AC Power'; then
            icon="󰂄"; color=${green}
          elif [ "$pct" -le 20 ]; then
            icon="󰁺"; color=${red}
          elif [ "$pct" -le 40 ]; then
            icon="󰁻"; color=${fg}
          elif [ "$pct" -le 60 ]; then
            icon="󰁾"; color=${fg}
          elif [ "$pct" -le 80 ]; then
            icon="󰂀"; color=${fg}
          else
            icon="󰁹"; color=${green}
          fi
          sketchybar --set "$NAME" icon="$icon" icon.color="$color" label="''${pct}%"
        '';
      };

      tailscaleScript = mkScript {
        name = "sketchybar-tailscale";
        runtimeInputs = [ pkgs.tailscale ];
        text = ''
          if tailscale status >/dev/null 2>&1; then
            sketchybar --set "$NAME" label="up" icon.color=${green}
          else
            sketchybar --set "$NAME" label="off" icon.color=${muted}
          fi
        '';
      };

      workspaceItems = lib.concatMapStringsSep "\n" (sid: ''
        sketchybar \
          --add item space.${sid} left \
          --subscribe space.${sid} aerospace_workspace_changed \
          --set space.${sid} icon=${sid} label.drawing=off background.drawing=on icon.padding_left=12 icon.padding_right=12 click_script="${pkgs.aerospace}/bin/aerospace workspace ${sid}" script="${workspaceScript}"
      '') workspaces;
    in
    {
      programs.sketchybar = {
        enable = true;
        service.enable = true;
        extraPackages = with pkgs; [
          aerospace
          coreutils
          gnugrep
          tailscale
        ];
        config.text = ''
          # Transparent floating bar — items carry their own pills, so there's no
          # oversized blurred strip behind them.
          sketchybar --bar \
            height=32 \
            position=top \
            y_offset=8 \
            margin=12 \
            color=0x00000000 \
            blur_radius=0 \
            shadow=off \
            sticky=on \
            padding_left=0 \
            padding_right=0

          sketchybar --default \
            background.corner_radius=9 \
            background.height=26 \
            background.color=${surface} \
            background.drawing=off \
            icon.font="${font}:Bold:14.0" \
            icon.color=${fg} \
            label.font="${font}:Semibold:13.0" \
            label.color=${fg} \
            padding_left=3 \
            padding_right=3 \
            icon.padding_left=8 \
            icon.padding_right=6 \
            label.padding_left=2 \
            label.padding_right=8

          # --- left: workspaces + focused app ---
          sketchybar --add event aerospace_workspace_changed
          ${workspaceItems}

          sketchybar \
            --add item front_app left \
            --subscribe front_app front_app_switched \
            --set front_app icon.drawing=off background.drawing=on label.color=${accent} script="${frontAppScript}"

          # --- right: status cluster (one pill) ---
          sketchybar \
            --add item volume right \
            --subscribe volume volume_change \
            --set volume script="${volumeScript}"

          sketchybar \
            --add item battery right \
            --set battery update_freq=30 icon=󰁹 script="${batteryScript}"

          sketchybar \
            --add item clock right \
            --set clock update_freq=10 icon=󰅐 icon.color=${accent} script="${clockScript}" \
            --subscribe clock system_woke

          sketchybar \
            --add item tailscale right \
            --set tailscale update_freq=10 icon=󰖂 script="${tailscaleScript}"

          sketchybar \
            --add bracket status volume battery clock tailscale \
            --set status background.drawing=on background.color=${surface}

          # Paint dynamic items now that everything exists.
          sketchybar --update
          sketchybar --trigger aerospace_workspace_changed
          sketchybar --trigger front_app_switched
          sketchybar --trigger volume_change INFO=50
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
