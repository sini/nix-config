# Wireshark. The programs.wireshark module + wireshark group are NixOS-only;
# macOS gets the GUI via the `wireshark-app` cask. termshark (TUI) is portable.
{
  den.aspects.apps.dev.networking.wireshark = {
    homebrew-cask = [ "wireshark-app" ];

    nixos =
      {
        pkgs,
        resolved-users,
        lib,
        ...
      }:
      {
        programs.wireshark = {
          enable = true;
          package = pkgs.wireshark;
        };

        users.users = lib.genAttrs (map (u: u.name) resolved-users) (_: {
          extraGroups = [ "wireshark" ];
        });
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.termshark
        ];
      };
  };
}
