{
  features.wireshark = {
    homeRequiresSystem = false; # termshark works standalone (capture needs group membership)
    system =
      {
        pkgs,
        host,
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
          }) host.users.enabledNames
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
