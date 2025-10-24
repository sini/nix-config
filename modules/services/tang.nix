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
      # environment.systemPackages = [ pkgs.tang ];

      # users = {
      #   users.tang = {
      #     group = "tang";
      #     isSystemUser = true;
      #   };
      #   groups.tang = { };
      # };

      # systemd.services."tangd@" = {
      #   description = "Tang server";
      #   path = [
      #     pkgs.jose
      #     pkgs.tang
      #   ];
      #   preStart = ''
      #     if ! test -n "$(${pkgs.findutils}/bin/find /var/lib/tang -maxdepth 1 -name '*.jwk' -print -quit)"; then
      #       ${pkgs.tang}/libexec/tangd-keygen /var/lib/tang
      #     fi
      #   '';
      #   serviceConfig = {
      #     StandardInput = "socket";
      #     StandardOutput = "socket";
      #     StandardError = "journal";
      #     User = "tang";
      #     Group = "tang";
      #     StateDirectory = "tang";
      #     StateDirectoryMode = "700";
      #     ExecStart = "${pkgs.tang}/libexec/tangd /var/lib/tang";
      #   };
      # };

      # systemd.sockets = {
      #   tangd = {
      #     description = "Tang server";
      #     wantedBy = [ "sockets.target" ];
      #     socketConfig = {
      #       ListenStream = 7654;
      #       Accept = "yes";
      #       IPAddressDeny = "any";
      #       IPAddressAllow = "10.0.0.0/8"; # TODO: Pull from environment or make configurable...
      #     };
      #   };
      # };

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
