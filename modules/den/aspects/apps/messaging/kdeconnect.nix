{ den, ... }:
{
  den.aspects.kdeconnect = {
    _ = {
      system = den.lib.perHost {
        nixos = {
          networking.firewall =
            let
              ports = [
                {
                  from = 1714;
                  to = 1764;
                }
              ];
            in
            {
              allowedTCPPortRanges = ports;
              allowedUDPPortRanges = ports;
            };
        };
      };

      home = den.lib.perUser {
        homeManager = {
          services.kdeconnect = {
            enable = true;
            indicator = true;
          };
        };

        persistHome.directories = [
          ".config/kdeconnect"
        ];
      };
    };
  };
}
