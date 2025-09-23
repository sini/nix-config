{ inputs, ... }:
let
  base16Scheme = {
    # You can use a file path to a JSON or YAML file
    # path = ./path/to/your/scheme.yaml;

    # Or define colors inline (based on Catppuccin Macchiato from your waybar config)
    # scheme = "Catppuccin Macchiato";
    # base00 = "#24273a"; # base
    # base01 = "#1e2030"; # mantle
    # base02 = "#363a4f"; # surface0
    # base03 = "#494d64"; # surface1
    # base04 = "#5b6078"; # surface2
    # base05 = "#cad3f5"; # text
    # base06 = "#f4dbd6"; # rosewater
    # base07 = "#b7bdf8"; # lavender
    # base08 = "#ed8796"; # red
    # base09 = "#f5a97f"; # peach
    # base0A = "#eed49f"; # yellow
    # base0B = "#a6da95"; # green
    # base0C = "#8bd5ca"; # teal
    # base0D = "#8aadf4"; # blue
    # base0E = "#c6a0f6"; # mauve
    # base0F = "#f5bde6"; # pink

    # scheme = "Catppuccin Mocha";
    base00 = "#1e1e2e"; # base
    base01 = "#181825"; # mantle
    base02 = "#313244"; # surface0
    base03 = "#45475a"; # surface1
    base04 = "#585b70"; # surface2
    base05 = "#cdd6f4"; # text
    base06 = "#f5e0dc"; # rosewater
    base07 = "#b4befe"; # lavender
    base08 = "#f38ba8"; # red
    base09 = "#fab387"; # peach
    base0A = "#f9e2af"; # yellow
    base0B = "#a6e3a1"; # green
    base0C = "#94e2d5"; # teal
    base0D = "#89b4fa"; # blue
    base0E = "#cba6f7"; # mauve
    base0F = "#f2cdcd"; # flamingo
  };
in
{
  flake.modules = {
    nixos.stylix =
      { pkgs, ... }:
      {
        imports = [
          inputs.stylix.nixosModules.stylix
        ];

        config = {
          programs.dconf.enable = true;

          stylix = {
            inherit base16Scheme;

            enable = true;
            autoEnable = true;
            homeManagerIntegration.autoImport = false;
            homeManagerIntegration.followSystem = false;

            image = pkgs.nixos-artwork.wallpapers.stripes-logo.gnomeFilePath;

            polarity = "dark";

            cursor = {
              name = "catppuccin-mocha-peach-cursors";
              size = 32;
              package = pkgs.catppuccin-cursors.mochaPeach;
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

          # Make stylix home-manager modules available to all users
          home-manager.sharedModules = [
            inputs.stylix.homeModules.stylix
          ];

        };
      };

    homeManager.stylix =
      { pkgs, ... }:
      {
        gtk = {
          enable = true;
          gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
          gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
        };
        dconf.settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
          };
        };
        stylix = {
          inherit base16Scheme;

          enable = true;
          autoEnable = true;

          image = pkgs.nixos-artwork.wallpapers.stripes-logo.gnomeFilePath;

          polarity = "dark";

          iconTheme = {
            enable = true;
            package = pkgs.catppuccin-papirus-folders.override {
              flavor = "mocha";
              accent = "lavender";
            };
            dark = "Papirus-Dark";
          };

          targets = {
            # TODO:  Hyprpaper is segfaulting for some reason, look into this
            hyprland.hyprpaper.enable = false;
            firefox = {
              firefoxGnomeTheme.enable = true;
              profileNames = [ "default" ];
            };
          };

          cursor = {
            name = "catppuccin-mocha-peach-cursors";
            size = 32;
            package = pkgs.catppuccin-cursors.mochaPeach;
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
              name = "DejaVuSansM Nerd Font Mono";
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
