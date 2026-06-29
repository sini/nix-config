# Trackpad: tap-to-click and natural scrolling.
{
  den.aspects.macos.defaults.trackpad.darwin = {
    system.defaults.trackpad = {
      Clicking = true;
      # Two-finger / bottom-right-corner secondary (right) click.
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = false;
    };

    system.defaults.NSGlobalDomain = {
      # Tap to click (mirrors the trackpad domain for external mice/older APIs).
      "com.apple.mouse.tapBehavior" = 1;
      # Natural ("content tracks fingers") scroll direction.
      "com.apple.swipescrolldirection" = true;
    };
  };
}
