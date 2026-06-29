# Keyboard behaviour: caps->ctrl remap, fast key repeat, function keys, and
# disabling the "smart" substitutions that mangle text in code/terminals.
{
  den.aspects.macos.defaults.keyboard.darwin = {
    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    system.defaults.NSGlobalDomain = {
      # Disable press-and-hold accent popup so key repeat works everywhere.
      ApplePressAndHoldEnabled = false;
      # Full keyboard access: Tab moves between all controls, not just text boxes.
      AppleKeyboardUIMode = 3;
      # F-keys act as F1..F12 by default (use fn for media keys).
      "com.apple.keyboard.fnState" = true;
      # Fastest comfortable repeat. InitialKeyRepeat min 15 (225ms),
      # KeyRepeat min 2 (30ms).
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      # Off: these rewrite what you type and fight code/markdown/terminals.
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };
  };
}
