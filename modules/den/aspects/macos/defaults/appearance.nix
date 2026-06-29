# System appearance, menu-bar clock, sound, and privacy defaults.
{
  den.aspects.macos.defaults.appearance.darwin = {
    system.defaults.NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      # Drag any window by holding ctrl+cmd anywhere in it.
      NSWindowShouldDragOnGesture = true;
      # Silence the alert beep.
      "com.apple.sound.beep.volume" = 0.0;
      "com.apple.sound.beep.feedback" = 0;
      # 24-hour time everywhere (apps that honour ICU), matching the menu clock.
      AppleICUForce24HourTime = true;
      # Click the scroll bar track to jump to that spot, not page-by-page.
      AppleScrollerPagingBehavior = true;
      # Snappier UI: near-instant window resize, no open/close animation.
      NSWindowResizeTime = 1.0e-3;
      NSAutomaticWindowAnimationsEnabled = false;
      # New documents save to disk, not iCloud, by default.
      NSDocumentSaveNewDocumentsToCloud = false;
      # Auto-hide the native menu bar; sketchybar owns the top edge. Push the
      # cursor to the top to reveal it.
      _HIHideMenuBar = true;
    };

    # Verbose menu-bar clock.
    system.defaults.menuExtraClock = {
      ShowDayOfWeek = true;
      ShowDate = 1;
      Show24Hour = true;
    };

    # No Apple-personalised ads.
    system.defaults.CustomUserPreferences."com.apple.AdLib".allowApplePersonalizedAdvertising = false;

    # Don't write .DS_Store files onto network or USB volumes.
    system.defaults.CustomUserPreferences."com.apple.desktopservices" = {
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };
  };
}
