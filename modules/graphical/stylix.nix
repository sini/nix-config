{ inputs, config, ... }:
{
  flake.modules = {
    nixos.stylix =
      { pkgs, ... }:
      {
        imports = [
          inputs.stylix.nixosModules.stylix
        ];

        config = {
          stylix = {
            enable = true;
            autoEnable = true;
            homeManagerIntegration.autoImport = false;
            homeManagerIntegration.followSystem = false;

            base16Scheme = {
              # You can use a file path to a JSON or YAML file
              # path = ./path/to/your/scheme.yaml;

              # Or define colors inline (based on Catppuccin Macchiato from your waybar config)
              # scheme = "Catppuccin Macchiato";
              base00 = "#24273a"; # base
              base01 = "#1e2030"; # mantle
              base02 = "#363a4f"; # surface0
              base03 = "#494d64"; # surface1
              base04 = "#5b6078"; # surface2
              base05 = "#cad3f5"; # text
              base06 = "#f4dbd6"; # rosewater
              base07 = "#b7bdf8"; # lavender
              base08 = "#ed8796"; # red
              base09 = "#f5a97f"; # peach
              base0A = "#eed49f"; # yellow
              base0B = "#a6da95"; # green
              base0C = "#8bd5ca"; # teal
              base0D = "#8aadf4"; # blue
              base0E = "#c6a0f6"; # mauve
              base0F = "#f5bde6"; # pink
            };

            image = pkgs.nixos-artwork.wallpapers.stripes-logo.gnomeFilePath;

            cursor = {
              name = "Bibata-Modern-Classic";
              package = pkgs.bibata-cursors;
              size = 24;
            };

            fonts = {
              sizes = {
                terminal = 12;
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
            ];

        };
      };

    homeManager.stylix =
      { pkgs, ... }:
      {
        stylix = {
          enable = true;
          autoEnable = true;

          base16Scheme = {
            # You can use a file path to a JSON or YAML file
            # path = ./path/to/your/scheme.yaml;

            # Or define colors inline (based on Catppuccin Macchiato from your waybar config)
            # scheme = "Catppuccin Macchiato";
            base00 = "#24273a"; # base
            base01 = "#1e2030"; # mantle
            base02 = "#363a4f"; # surface0
            base03 = "#494d64"; # surface1
            base04 = "#5b6078"; # surface2
            base05 = "#cad3f5"; # text
            base06 = "#f4dbd6"; # rosewater
            base07 = "#b7bdf8"; # lavender
            base08 = "#ed8796"; # red
            base09 = "#f5a97f"; # peach
            base0A = "#eed49f"; # yellow
            base0B = "#a6da95"; # green
            base0C = "#8bd5ca"; # teal
            base0D = "#8aadf4"; # blue
            base0E = "#c6a0f6"; # mauve
            base0F = "#f5bde6"; # pink
          };

          image = pkgs.nixos-artwork.wallpapers.stripes-logo.gnomeFilePath;

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

          cursor = {
            name = "Bibata-Modern-Classic";
            package = pkgs.bibata-cursors;
            size = 24;
          };

          fonts = {
            sizes = {
              terminal = 12;
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
