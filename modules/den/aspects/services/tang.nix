{ den, lib, ... }:
{
  den.aspects.tang = {
    includes = lib.attrValues den.aspects.tang._;

    _ = {
      config = den.lib.perHost {
        nixos = {
          services.tang = {
            enable = true;
            ipAddressAllow = [
              "10.0.0.0/8"
            ];
          };
        };
      };

      firewall = den.lib.perHost {
        firewall.allowedTCPPorts = [ 7654 ];
      };

      impermanence = den.lib.perHost {
        persist.directories = [
          {
            directory = "/var/lib/private/tang";
            user = "nobody";
            group = "nogroup";
            mode = "0700";
          }
        ];
      };
    };
  };
}
