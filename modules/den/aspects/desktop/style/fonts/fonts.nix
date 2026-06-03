{ den, ... }:
{
  den.aspects.desktop.style.fonts = {
    includes = [
      den.aspects.desktop.style.fonts.nerd-fonts
      den.aspects.desktop.style.fonts.regular
    ];

    nixos = {
      fonts = {
        enableDefaultPackages = true;
        fontDir.enable = true;

        fontconfig = {
          enable = true;
          useEmbeddedBitmaps = true;
          localConf = ''
            <?xml version="1.0"?>
            <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
            <fontconfig>
              <dir>/usr/local/share/fonts/t</dir>
            </fontconfig>
          '';
          defaultFonts = {
            monospace = [ "Monaspace Neon NF" ];
            sansSerif = [ "Inter" ];
            serif = [ "Source Serif" ];
            emoji = [ "OpenMoji Color" ];

          };
        };
      };
    };

    homeManager = {
      fonts.fontconfig.enable = true;
    };
  };
}
