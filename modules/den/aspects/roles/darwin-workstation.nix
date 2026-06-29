# Slimmed-down macOS workstation: the graphical/experience layer that sits on top
# of roles.default + roles.dev. Mirrors roles.workstation for Linux but carries
# only what makes sense on Darwin (stylix theming, fonts, homebrew casks, the
# aerospace/sketchybar/jankyborders stack, macOS defaults, Spotlight fix).
{ den, ... }:
{
  den.aspects.roles.darwin-workstation = {
    includes = with den.aspects; [
      # Theming
      desktop.style.stylix

      # System
      macos.fonts
      macos.homebrew
      macos.spotlight-apps

      # macOS defaults
      macos.defaults.keyboard
      macos.defaults.dock
      macos.defaults.finder
      macos.defaults.trackpad
      macos.defaults.appearance
      macos.defaults.keybindings
      macos.defaults.screencapture
      macos.defaults.security

      # Window manager
      macos.wm.aerospace
      macos.wm.jankyborders
      macos.wm.sketchybar

      # GUI apps (native nixpkgs where it builds on darwin, homebrew cask where
      # it doesn't — see each aspect's homebrew-cask contribution).
      apps.browsers.firefox
      apps.browsers.chromium
      apps.terminals.kitty
      apps.terminals.alacritty
      apps.dev.editor.vscode
      apps.dev.git.gitkraken
      apps.dev.networking.wireshark
      apps.productivity.obsidian
      apps.productivity.obs-studio
      apps.mail.protonmail
    ];
  };
}
