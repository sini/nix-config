{
  flake.modules = {
    nixos.fonts =
      { pkgs, ... }:
      {
        fonts = {
          packages = with pkgs; [
            nerd-fonts.symbols-only
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-cjk-serif
            noto-fonts-emoji
            noto-fonts-extra

            nerd-fonts.dejavu-sans-mono
            nerd-fonts.ubuntu-mono

            dejavu_fonts
            segoe-ui-ttf
            jetbrains-mono

            dina-font
            aporetic
            monaspace
          ];
          fontconfig = {
            defaultFonts = {
              monospace = [
                "Aporetic Sans Mono"
              ];
              sansSerif = [ "Aporetic Sans Mono" ];
              serif = [ "Aporetic Sans Mono" ];
            };
          };
        };
      };

    homeManager.fonts = {
      fonts.fontconfig.enable = true;
    };
  };
}
