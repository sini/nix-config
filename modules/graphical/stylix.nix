{ inputs, config, ... }:
{
  flake.modules = {
    nixos.stylix =
      { pkgs, ... }:
      {
        imports = [ inputs.stylix.nixosModules.stylix ];
        config = {
          stylix = {
            enable = true;
            autoEnable = true;
            base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
            homeManagerIntegration.autoImport = false;
            homeManagerIntegration.followSystem = false;

            # image = pkgs.nixicle.wallpapers.windows-error;

            cursor = {
              name = "Bibata-Modern-Classic";
              package = pkgs.bibata-cursors;
              size = 24;
            };

            fonts = {
              sizes = {
                terminal = 14;
                applications = 12;
                popups = 12;
              };

              serif = {
                name = "Source Serif";
                package = pkgs.source-serif;
              };

              sansSerif = {
                name = "Noto Sans";
                package = pkgs.noto-fonts;
              };

              monospace = {
                package = pkgs.nerd-fonts.dejavu-sans-mono;
                name = "DejaVu Sans Mono";
              };

              emoji = {
                package = pkgs.noto-fonts-emoji;
                name = "Noto Color Emoji";
              };
            };
          };

          home-manager.users.${config.flake.meta.user.username}.imports =
            with config.flake.modules.homeManager; [
              stylix
              inputs.stylix.homeModules.stylix
              inputs.catppuccin.homeModules.catppuccin
            ];

        };
      };

    homeManager.stylix =
      { pkgs, ... }:
      {
        catppuccin.flavor = "mocha";
        catppuccin.enable = true;
        stylix = {
          enable = true;
          autoEnable = true;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

          iconTheme = {
            enable = true;
            package = pkgs.catppuccin-papirus-folders.override {
              flavor = "mocha";
              accent = "lavender";
            };
            dark = "Papirus-Dark";
          };

          targets = {
            firefox = {
              firefoxGnomeTheme.enable = true;
              profileNames = [ "default" ];
            };
          };

          image = pkgs.nixicle.wallpapers.nixppuccin;

          cursor = {
            name = "Bibata-Modern-Classic";
            package = pkgs.bibata-cursors;
            size = 24;
          };

          fonts = {
            sizes = {
              terminal = 14;
              applications = 12;
              popups = 12;
            };

            serif = {
              name = "Source Serif";
              package = pkgs.source-serif;
            };

            sansSerif = {
              name = "Noto Sans";
              package = pkgs.noto-fonts;
            };

            monospace = {
              package = pkgs.nerd-fonts.dejavu-sans-mono;
              name = "DejaVu Sans Mono";
            };

            emoji = {
              package = pkgs.noto-fonts-emoji;
              name = "Noto Color Emoji";
            };
          };
        };
      };
  };
}
