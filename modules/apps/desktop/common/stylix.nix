{
  flake.features.stylix = {
    nixos =
      { inputs, pkgs, ... }:
      {
        imports = [
          inputs.stylix.nixosModules.stylix
        ];

        config = {
          programs.dconf.enable = true;

          stylix = {
            base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-storm.yaml";

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
                package = pkgs.noto-fonts-color-emoji;
                name = "Noto Color Emoji";
              };
            };
          };

          # Make stylix home-manager modules available to all users
          home-manager.sharedModules = [
            inputs.stylix.homeModules.stylix
          ];

          environment.persistence."/persist".directories = [
            {
              directory = "/var/lib/colord";
              user = "colord";
              group = "colord";
              mode = "0755";
            }
          ];
        };
      };

    home =
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
          base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-storm.yaml";

          enable = true;
          autoEnable = true;

          image = pkgs.fetchurl {
            url = "https://w.wallhaven.cc/full/qr/wallhaven-qrd6xd.png";
            hash = "sha256-ZS/ALvkETellw2squBX7bRmx1VURGQ9SAvQIjTuP9FI=";
          };

          # pkgs.nixos-artwork.wallpapers.stripes-logo.gnomeFilePath;

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
              package = pkgs.noto-fonts-color-emoji;
              name = "Noto Color Emoji";
            };
          };
        };
      };
  };
}
