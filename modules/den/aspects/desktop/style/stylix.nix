{ inputs, ... }:
let
  # Named wallpapers kept for reference. Stylix themes a single image per
  # generation (no runtime switching — use nix-darwin specialisations for
  # multiple switchable theme variants), so pick the active one in `wallpaper`
  # below. This is the single source shared by the home-manager and darwin
  # stylix images and the macOS desktoppr setter.
  wallpapers = pkgs: {
    wallpaperaccess-17036190 = pkgs.fetchurl {
      url = "https://wallpaperaccess.com/full/17036190.jpg";
      hash = "sha256-D2lCIxuEbm3tsvZZoJ8C56/SmWiuCBafJ7UZ9jztng4=";
    };
    wallhaven-qrd6xd = pkgs.fetchurl {
      url = "https://w.wallhaven.cc/full/qr/wallhaven-qrd6xd.png";
      hash = "sha256-ZS/ALvkETellw2squBX7bRmx1VURGQ9SAvQIjTuP9FI=";
    };
  };
  wallpaper = pkgs: (wallpapers pkgs).wallpaperaccess-17036190;
in
{
  den.aspects.desktop.style.stylix = {
    nixos =
      {
        pkgs,
        ...
      }:
      {
        imports = [
          inputs.stylix.nixosModules.stylix
        ];

        config = {
          programs.dconf.enable = true;

          stylix = {
            base16Scheme = "${inputs.base16-schemes}/base16/tokyo-night-moon.yaml";

            enable = true;
            enableReleaseChecks = false;
            autoEnable = true;

            homeManagerIntegration.autoImport = false;
            homeManagerIntegration.followSystem = false;

            image = pkgs.nixos-artwork.wallpapers.stripes-logo.gnomeFilePath;

            polarity = "dark";

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
        };
      };

    darwin =
      { pkgs, ... }:
      {
        imports = [
          inputs.stylix.darwinModules.stylix
        ];

        stylix = {
          base16Scheme = "${inputs.base16-schemes}/base16/tokyo-night-moon.yaml";

          enable = true;
          enableReleaseChecks = false;
          autoEnable = true;

          # home-manager stylix is configured separately (homeManager block).
          homeManagerIntegration.autoImport = false;
          homeManagerIntegration.followSystem = false;

          image = wallpaper pkgs;

          polarity = "dark";

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
              name = "DejaVuSansM Nerd Font Mono";
              package = pkgs.nerd-fonts.dejavu-sans-mono;
            };

            emoji = {
              name = "Noto Color Emoji";
              package = pkgs.noto-fonts-color-emoji;
            };
          };
        };
      };

    # stylix has no macOS wallpaper target, so apply the themed image with
    # desktoppr (reliable on current macOS) on each activation.
    homeDarwin =
      { config, pkgs, ... }:
      {
        home.activation.setWallpaper = config.lib.dag.entryAfter [ "writeBoundary" ] ''
          run ${pkgs.desktoppr}/bin/desktoppr "${config.stylix.image}" || true
        '';
      };

    persist = {
      directories = [
        {
          directory = "/var/lib/colord";
          user = "colord";
          group = "colord";
          mode = "0755";
        }
      ];
    };

    homeLinux =
      { pkgs, ... }:
      {
        stylix = {
          icons = {
            enable = true;
            package = pkgs.catppuccin-papirus-folders.override {
              flavor = "mocha";
              accent = "lavender";
            };
            dark = "Papirus-Dark";
          };

          targets.firefox.firefoxGnomeTheme.enable = true;

          cursor = {
            name = "catppuccin-mocha-peach-cursors";
            size = 32;
            package = pkgs.catppuccin-cursors.mochaPeach;
          };
        };
      };

    homeManager =
      {
        pkgs,
        stylix-hm,
        lib,
        ...
      }:
      {
        imports = [
          inputs.stylix.homeModules.stylix
        ];

        stylix = lib.mkMerge (
          stylix-hm
          ++ [
            {
              base16Scheme = "${inputs.base16-schemes}/base16/tokyo-night-moon.yaml";

              enable = true;
              enableReleaseChecks = false;
              autoEnable = true;

              image = wallpaper pkgs;

              polarity = "dark";

              targets = {
                qt.enable = false;
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
            }
          ]
        );
      };
  };
}
