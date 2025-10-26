{
  # We are having issues with the nixpkg socket... so lets stash our own service for now with fixed users.
  flake.features.tang.nixos =
    # { pkgs, ... }:
    {

      services.tang = {
        enable = true;
        ipAddressAllow = [
          "10.0.0.0/8"
        ];
      };

      networking.firewall.allowedTCPPorts = [ 7654 ];

      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/private/tang";
          user = "nobody";
          group = "nogroup";
          mode = "0700";
        }
      ];
    };
}
