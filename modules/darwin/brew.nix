{ inputs, ... }:
{
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  environment.systemPath = [ "/opt/homebrew/bin" ];

  nix-homebrew = {
    enable = true;
    enableRosetta = false;

    # TODO(clo4): make another user to own the homebrew prefix
    # because things get annoying when you add another user to
    # the machine that also wants to use brew.
    # This isn't a problem *yet*, but it's not a matter of 'if'
    # it will be, just when.
    user = "sini";

    # All taps must be declared below.
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
    };
  };

  homebrew = {
    enable = true;

    brews = [
      # Using the java managed by homebrew for compatibility with Mincecraft launchers
      "java"
    ];

    # Applications are installed through Homebrew because there's a wider selection available
    # on macOS and the applications tend to be more up-to-date.
    # The other reason is that applications installed via Nix tend to break in the dock because
    # of the way the volume mounts - it's been a while but from what I remember the icons weren't
    # working correctly, or maybe it's that opening them on startup was having problems?
    casks = [
      # NOTE: Homerow isn't available as a cask yet

      #"1password"

      # Media tools
      "audio-hijack"
      "loopback"
      "blender"
      "coreutils"

      # Loosely, productivity
      "raycast"
      "appcleaner"
      "shottr"
      "keka"
      "karabiner-elements" # Might make a module for this in the future...

      # Loosely, social platforms
      "signal"
      "discord"
      "steam"

      "cursorcerer"
      "docker"
      "firefox"
      "grandperspective"
      "iina"
      "monitorcontrol"
      "obs"
      "obsidian"
      "plover"
      "rectangle"
      "spotify"
      "transmission"
      "utm"
      "wezterm"
      "zed"
    ];
  };
}
