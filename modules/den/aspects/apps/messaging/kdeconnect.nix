{ den, ... }:
{
  den.aspects.apps.kdeconnect = {
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

    homeManager = {
      services.kdeconnect = {
        enable = true;
        indicator = true;
      };
    };

    provides.impermanence = {
      homeManager = {
        home.persistence."/persist".directories = [
          ".config/kdeconnect"
        ];
      };
    };
  };
}
