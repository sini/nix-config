{
  # This needs to be reapplied after system updates
  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    primaryUser = "sini"; # TODO: Make this dynamic

    defaults = {
      CustomUserPreferences = {
        NSGlobalDomain = {
          NSWindowShouldDragOnGesture = true;
        };
        "com.superultra.homerow" = {
          label-characters = "arstneiowfpluy";
          scroll-keys = "mnei";
          map-arrow-keys-to-scroll = false;
          launch-at-login = true;
          is-experimental-support-enabled = true;
          # The shortcut really is stored as the shift symbol and command symbol!
          non-search-shortcut = "⇧⌘Space";
        };
      };

      NSGlobalDomain = {
        # Automatic dark mode at night
        # AppleInterfaceStyleSwitchesAutomatically = true;

        # Disabling this means you can hold to repeat keys
        ApplePressAndHoldEnabled = false;
        AppleShowAllExtensions = true;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSWindowShouldDragOnGesture = true;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        # Enables using the function keys as the F<number> key instead of OS controls
        "com.apple.keyboard.fnState" = true;
        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.feedback" = 0;
      };

      dock = {
        autohide = true;
        show-recents = false;
        launchanim = true;
        mouse-over-hilite-stack = true;
        orientation = "bottom";
        tilesize = 48;
      };

      finder = {
        # Shows a breadcrumb trail down the bottom of the Finder window
        ShowPathbar = true;

        # Hides desktop icons (but they're still accessible through Finder).
        # Because it never creates a desktop, you can't *click* on the desktop.
        CreateDesktop = false;

        # This magic string makes it search the current folder by default
        FXDefaultSearchScope = "SCcf";

        # Use the column view by default (the obviously correct and best view)
        FXPreferredViewStyle = "clmv";
      };
    };
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
  };
}
