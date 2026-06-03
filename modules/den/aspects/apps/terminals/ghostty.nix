{
  den.aspects.apps.terminals.ghostty = {
    homeManager =
      {
        pkgs,
        ...
      }:
      {
        programs.ghostty = {
          enable = true;
          package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
          enableZshIntegration = true;
          settings = {
            # Ghostty's fixterms encoding sends Ctrl+[ as ^[[91;5u instead of the
            # traditional \x1b, which zsh vi-mode doesn't recognize.  This remaps it
            # back to plain ESC so vi-cmd-mode triggers correctly.
            keybind = "ctrl+bracket_left=text:\\x1b";
            maximize = true;
            # This keeps the title bar from being totally black so I can't tell where
            # the title bar ends and the terminal background begins.
            macos-titlebar-style = "native";
            # display-p3 makes colors match Terminal.app's vibrancy.  Terminal.app
            # passes palette hex values through to the display natively rather than
            # converting from sRGB, so using display-p3 here matches that behavior.
            window-colorspace = "display-p3";
            font-family = "Source Code Pro";
            font-size = 14;
            # Ghostty's GPU renderer produces thinner strokes than Terminal.app's
            # CoreText renderer.  On dark backgrounds this makes colored text appear
            # faded and harder to tell apart.  font-thicken compensates (macOS only).
            font-thicken = true;
            # The paste-protection dialog displays clipboard contents in plain text,
            # which leaks passwords pasted into prompts with echo disabled.
            clipboard-paste-protection = false;
          };
        };
      };
  };
}
