{ den, ... }:
{
  den.aspects.wireshark = {
    _ = {
      system = den.lib.perHost (
        { host }:
        {
          nixos =
            { pkgs, ... }:
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
        }
      );

      home = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = with pkgs; [
              termshark
            ];
          };
      };
    };
  };
}
