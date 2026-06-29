# Raycast launcher. macOS-only GUI app with no nixpkgs build, so it comes via
# cask. Free up Cmd-Space by disabling the Spotlight shortcut so Raycast can
# claim it on first launch.
{
  den.aspects.macos.apps.raycast = {
    homebrew-cask = [ "raycast" ];

    darwin = {
      # "Show Spotlight search" is symbolic hotkey 64 (Cmd-Space). Disabling it
      # lets Raycast bind Cmd-Space without a conflict.
      system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys."64".enabled =
        false;
    };
  };
}
