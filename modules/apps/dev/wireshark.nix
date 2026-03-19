{
  features.wireshark = {
    system =
      {
        lib,
        pkgs,
        users,
        ...
      }:
      {
        programs = {
          wireshark = {
            enable = true;
            package = pkgs.wireshark;
          };
        };

        # Add all enabled users to the wireshark group
        users.users = builtins.listToAttrs (
          map (userName: {
            name = userName;
            value = {
              extraGroups = [ "wireshark" ];
            };
          }) (builtins.attrNames (lib.filterAttrs (_: u: u.system.enable or false) users))
        );
      };

    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          termshark
        ];
      };
  };
}
