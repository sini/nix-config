# Finder: column view, full paths, all files visible, folders first — a
# developer-oriented file browser instead of the consumer defaults.
{
  den.aspects.macos.defaults.finder.darwin = {
    system.defaults.finder = {
      ShowPathbar = true;
      ShowStatusBar = true;
      # Column view everywhere; search the current folder, not the whole Mac.
      FXPreferredViewStyle = "clmv";
      FXDefaultSearchScope = "SCcf";
      # Don't nag when changing a file extension.
      FXEnableExtensionChangeWarning = false;
      _FXSortFoldersFirst = true;
      # Auto-size columns to fit names (pairs with the column view above).
      _FXEnableColumnAutoSizing = true;
      # Full POSIX path in the window title bar.
      _FXShowPosixPathInTitle = true;
      AppleShowAllFiles = true;
      NewWindowTarget = "Home";
      # Allow quitting Finder with Cmd-Q like any other app.
      QuitMenuItem = true;
      # Don't litter the desktop with icons (we hide it anyway).
      CreateDesktop = false;
    };

    system.defaults.NSGlobalDomain = {
      AppleShowAllExtensions = true;
      # Default save/print panels to expanded so the full file browser shows.
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
    };

    # Stage Manager off / classic desktop behaviour. Also disable macOS's own
    # edge-drag tiling so it doesn't fight the aerospace tiling WM.
    system.defaults.WindowManager = {
      GloballyEnabled = false;
      EnableStandardClickToShowDesktop = false;
      StageManagerHideWidgets = false;
      EnableTilingByEdgeDrag = false;
      EnableTopTilingByEdgeDrag = false;
    };
  };
}
