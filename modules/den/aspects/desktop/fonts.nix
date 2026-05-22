{ den, ... }:
{
  den.aspects.desktop.fonts = {
    nixos =
      { pkgs, ... }:
      {
        fonts = {
          enableDefaultPackages = true;
          fontDir.enable = true;
          packages = [
            pkgs.source-code-pro

            pkgs.nerd-fonts.symbols-only
            pkgs.noto-fonts
            pkgs.noto-fonts-cjk-sans
            pkgs.noto-fonts-cjk-serif
            pkgs.noto-fonts-color-emoji

            pkgs.nerd-fonts.dejavu-sans-mono
            pkgs.nerd-fonts.fira-code
            pkgs.nerd-fonts.meslo-lg
            pkgs.nerd-fonts.symbols-only
            pkgs.nerd-fonts.ubuntu-mono
            pkgs.nerd-fonts.terminess-ttf

            pkgs.dejavu_fonts
            pkgs.jetbrains-mono

            pkgs.dina-font
            pkgs.aporetic
            pkgs.monaspace

            pkgs.openmoji-color
            pkgs.twemoji-color-font
          ];

          fontconfig = {
            enable = true;
            useEmbeddedBitmaps = true;
            localConf = ''
              <?xml version="1.0"?>
              <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
              <fontconfig>
                <!-- Add Symbols Nerd Font as a global fallback -->
                <match target="pattern">
                  <test name="family" compare="not_eq">
                    <string>Symbols Nerd Font</string>
                  </test>
                  <edit name="family" mode="append">
                    <string>Symbols Nerd Font</string>
                  </edit>
                </match>
              </fontconfig>
            '';
            defaultFonts = {
              monospace = [ "DejaVuSansM Nerd Font Mono" ];
              sansSerif = [ "Noto Sans" ];
              serif = [ "Source Serif" ];
            };
          };
        };
      };

    homeManager = {
      fonts.fontconfig.enable = true;
    };
  };
}
