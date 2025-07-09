{
  flake.modules = {
    nixos.fonts =
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
            nerd-fonts.ubuntu-mono

            dejavu_fonts
            jetbrains-mono

            dina-font
            aporetic
            monaspace
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
