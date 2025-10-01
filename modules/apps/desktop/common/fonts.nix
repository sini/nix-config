{
  flake.aspects.fonts = {
    nixos =
      { pkgs, ... }:
      {
        fonts = {
          enableDefaultPackages = true;
          fontDir.enable = true;
          packages = with pkgs; [
            nerd-fonts.symbols-only
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-cjk-serif
            noto-fonts-emoji
            noto-fonts-extra

            nerd-fonts.dejavu-sans-mono
            nerd-fonts.fira-code
            nerd-fonts.meslo-lg
            nerd-fonts.symbols-only
            nerd-fonts.ubuntu-mono

            dejavu_fonts
            jetbrains-mono

            dina-font
            aporetic
            monaspace

            openmoji-color
            twemoji-color-font
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

    home = {
      fonts.fontconfig.enable = true;
    };
  };
}
