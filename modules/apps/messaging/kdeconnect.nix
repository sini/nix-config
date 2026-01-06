{
  flake.features.kdeconnect = {
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

    home = {
      services.kdeconnect = {
        enable = true;
        indicator = true;
      };

      home.persistence."/persist".directories = [
        ".config/kdeconnect"
      ];
    };
  };
}
