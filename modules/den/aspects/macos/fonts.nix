# Install the fleet fonts into the macOS font system (nix-darwin's fonts.packages
# writes to /Library/Fonts, which home-manager/stylix can't do on darwin). The
# DejaVu Nerd Font matches the stylix monospace that sketchybar renders with.
{
  den.aspects.macos.fonts.darwin =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        nerd-fonts.dejavu-sans-mono
        noto-fonts
        noto-fonts-color-emoji
        source-serif
      ];
    };
}
