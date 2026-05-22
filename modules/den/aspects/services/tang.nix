{ den, ... }:
{
  den.aspects.services.tang = {
    nixos = {
      services.tang = {
        enable = true;
        ipAddressAllow = [
          "10.0.0.0/8"
        ];
      };
    };

    firewall = {
      networking.firewall.allowedTCPPorts = [ 7654 ];
    };

    persist = {
      directories = [
        {
          directory = "/var/lib/private/tang";
          user = "nobody";
          group = "nogroup";
          mode = "0700";
        }
      ];
    };
  };
}
