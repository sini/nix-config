{
  den,
  lib,
  inputs,
  ...
}:
{
  den.aspects.stylix = {
    includes = lib.attrValues den.aspects.stylix._;

    _ = {
      nixos = den.lib.perHost {
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
                base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-moon.yaml";
                image = pkgs.fetchurl {
                  url = "https://w.wallhaven.cc/full/qr/wallhaven-qrd6xd.png";
                  hash = "sha256-ZS/ALvkETellw2squBX7bRmx1VURGQ9SAvQIjTuP9FI=";
                };

                enable = true;
                enableReleaseChecks = false;
                autoEnable = true;

                homeManagerIntegration.autoImport = true;
                homeManagerIntegration.followSystem = true;

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
      };

      impermanence = den.lib.perHost {
        nixos = _: {
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

      homeLinux = den.lib.perUser {
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

              targets.firefox = {
                firefoxGnomeTheme.enable = true;
                profileNames = [ "default" ];
              };

              cursor = {
                name = "catppuccin-mocha-peach-cursors";
                size = 32;
                package = pkgs.catppuccin-cursors.mochaPeach;
              };
            };
          };
      };

      # home sub-aspect removed — followSystem propagates NixOS stylix config to all HM users
    };
  };
}
