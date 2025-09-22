{
  flake.modules.nixos.wireshark =
    { pkgs, users, ... }:
    {
      programs = {
        wireshark = {
          enable = true;
          package = pkgs.wireshark;
        };
      };

      # Add all enabled users to the wireshark group
      users.users = builtins.listToAttrs (
        builtins.map (userName: {
          name = userName;
          value = {
            extraGroups = [ "wireshark" ];
          };
        }) (builtins.attrNames users)
      );
    };

  flake.modules.homeManager.wireshark =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        termshark
      ];
    };
}
