{ den, self, ... }:
{
  den.aspects.services.nix-remote-build-server = {
    nixos =
      { pkgs, lib, ... }:
      {
        services.nix-serve = {
          enable = true;
          package = pkgs.nix-serve-ng;
          # secretKeyFile wired via secrets quirk
          port = 16893;
          openFirewall = true;
        };

        nix.settings = {
          trusted-users = [ "nix-remote-build" ];
          allowed-users = [ "nix-remote-build" ];
        };

        users = {
          groups.nix-remote-build.name = "nix-remote-build";

          users.nix-remote-build = {
            group = "nix-remote-build";
            isSystemUser = true;
            useDefaultShell = true;
            description = "nix-remote-build";
            openssh.authorizedKeys.keys =
              lib.map (key: ''command="nix-store --serve --write",restrict '' + key)
                [ (builtins.readFile (self + "/.secrets/users/nix-remote-build/id_ed25519.pub")) ];
          };
        };
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [ 16893 ];
    };

    age-secrets = {
      age.secrets.nix_store_signing_key = {
        generator.script = "binary-cache-key";
        owner = "nix-serve";
        mode = "0400";
      };
    };
  };
}
