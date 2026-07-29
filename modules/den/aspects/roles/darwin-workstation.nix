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
      macos.applications.karabiner

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
      macos.applications.raycast
      applications.browsers.firefox
      applications.browsers.chromium
      applications.terminals.kitty
      applications.terminals.alacritty
      applications.dev.editor.codium.vscode
      applications.dev.editor.codium.core
      applications.dev.lang.c
      applications.dev.lang.go
      applications.dev.lang.lua
      applications.dev.lang.markdown
      applications.dev.lang.nix
      applications.dev.lang.python
      applications.dev.lang.shell
      applications.dev.git.gitkraken
      applications.dev.networking.wireshark
      applications.dev.security.opkssh-client
      applications.productivity.obsidian
      applications.productivity.obs-studio
      applications.mail.protonmail
    ];
  };
}
