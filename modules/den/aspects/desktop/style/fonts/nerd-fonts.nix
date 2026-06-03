{
  den.aspects.desktop.style.fonts.nerd-fonts = {
    nixos =
      { pkgs, ... }:
      {
        fonts.packages = with pkgs.nerd-fonts; [
          symbols-only
          adwaita-mono
          dejavu-sans-mono
          fira-mono
          fira-code
          jetbrains-mono
          meslo-lg
          ubuntu-mono
          terminess-ttf
        ];
      };
  };
}
