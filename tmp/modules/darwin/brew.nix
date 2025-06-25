{ config, inputs, ... }:
{
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  environment.systemPath = [ "/opt/homebrew/bin" ];

  nix-homebrew = {
    enable = true;
    enableRosetta = false;

    user = "sini"; # TODO: Make this dynamic

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
    global = {
      autoUpdate = true;
    };
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };
    brews = [
      "trash"
    ];

    taps = builtins.attrNames config.nix-homebrew.taps;

    casks = [
      # NOTE: Homerow isn't available as a cask yet
      "1password-cli"
      "1password"
      "alacritty"
      "betterdisplay"
      "caffeine"
      "discord"
      "dropbox"
      "exifcleaner"
      "firefox"
      "google-chrome"
      "handbrake"
      "linearmouse"
      "obsidian"
      "rar"
      "raycast"
      "screen-studio"
      "spotify"
      "steam"
      "the-unarchiver"
      "visual-studio-code"
      "vlc"
      "whatsapp"

      # Media tools
      "audio-hijack"
      "loopback"
      "blender"
      "coreutils"

      # Loosely, productivity
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

    masApps = {
      "1Password for Safari" = 1569813296;
    };
  };
}
