{ den, ... }:
{
  den.aspects.apps.wireshark = {
    nixos =
      {
        pkgs,
        host,
        ...
      }:
      {
        programs.wireshark = {
          enable = true;
          package = pkgs.wireshark;
        };

        users.users = builtins.listToAttrs (
          map (userName: {
            name = userName;
            value = {
              extraGroups = [ "wireshark" ];
            };
          }) host.users.enabledNames
        );
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
