# JankyBorders: a coloured outline around the focused window, themed from the
# fleet's stylix base16 palette (tokyo-night-moon) so it matches everything else.
{
  den.aspects.macos.wm.jankyborders.homeDarwin =
    { config, ... }:
    let
      inherit (config.lib.stylix) colors;
      # stylix gives "rrggbb"; jankyborders wants 0xAARRGGBB.
      argb = alpha: hex: "0x${alpha}${hex}";
    in
    {
      services.jankyborders = {
        enable = true;
        settings = {
          style = "round";
          active_color = argb "ff" colors.base0D; # accent / blue
          inactive_color = argb "80" colors.base03; # muted
          width = 6.0;
        };
      };

      # Reload the running borders agent so settings changes apply on activation.
      home.activation.restartJankyborders = config.lib.dag.entryAfter [ "setupLaunchAgents" ] ''
        run /bin/launchctl kickstart -k "gui/$UID/org.nix-community.home.jankyborders" || true
      '';
    };
}
