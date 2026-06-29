# Emacs-style text keybindings (word motions / word deletion) in every Cocoa
# text field. There is no system.defaults equivalent for these, so they go
# through home-manager's targets.darwin.keybindings on the Darwin home class.
# Ref: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/TextDefaultsBindings/TextDefaultsBindings.html
{
  den.aspects.macos.defaults.keybindings.homeDarwin = {
    targets.darwin.keybindings = {
      "\033" = "complete:"; # ESC -> completion
      "~b" = "moveWordBackward:";
      "~f" = "moveWordForward:";
      "~d" = "deleteWordForward:";
      "~\010" = "deleteWordBackward:"; # alt+backspace
      "~\177" = "deleteWordBackward:"; # alt+delete
      "~<" = "moveToBeginningOfDocument:";
      "~>" = "moveToEndOfDocument:";
      "~v" = "pageUp:";
    };
  };
}
