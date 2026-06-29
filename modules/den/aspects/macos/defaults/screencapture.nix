# Screenshots: drop them in a dedicated folder (not the desktop) and without the
# big drop-shadow border.
{
  den.aspects.macos.defaults.screencapture = {
    darwin = {
      system.defaults.screencapture = {
        location = "~/Pictures/Screenshots";
        disable-shadow = true;
        type = "png";
      };
    };

    # macOS silently falls back to the desktop if the folder doesn't exist, so
    # make sure it's there.
    homeDarwin = {
      home.file."Pictures/Screenshots/.keep".text = "";
    };
  };
}
