{ config, ... }:
let
  username = config.flake.meta.user.username;
in
{
  flake.modules.nixos.wireshark =
    { pkgs, ... }:
    {
      programs = {
        wireshark = {
          enable = true;
          package = pkgs.wireshark;
        };
      };

      users.users.${username}.extraGroups = [
        "wireshark"
      ];

      home-manager.users.${username}.imports = with config.flake.modules.homeManager; [
        wireshark
      ];
    };

  flake.modules.homeManager.wireshark =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        termshark
      ];
    };
}
