{ den, ... }:
{
  den.aspects.desktop.style.fonts.regular = {
    includes = [
      (den.batteries.unfree [
        "corefonts"
        "vista-fonts"
      ])
    ];

    nixos =
      { pkgs, ... }:
      {
        fonts.packages =
          with pkgs;
          [
            adwaita-fonts
            aporetic
            atkinson-hyperlegible-next
            corefonts
            dejavu_fonts
            dina-font
            fira
            font-awesome
            googlesans-code
            inter
            jetbrains-mono
            libertine
            maple-mono.NF
            material-icons
            material-symbols
            monaspace
            montserrat
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-cjk-serif
            noto-fonts-color-emoji
            openmoji-color
            source-code-pro
            twemoji-color-font
            vista-fonts
          ]
          ++ [
            # Local font pkgs...
            pkgs.local.feather
            pkgs.local.sf-mono
            pkgs.local.sf-pro
          ];
      };
  };
}
