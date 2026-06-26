{ self, ... }:
{
  den.aspects.services.nix.remote-build-server = {
    nixos =
      {
        config,
        pkgs,
        lib,
        resolved-users,
        ...
      }:
      {
        services.nix-serve = {
          enable = true;
          package = pkgs.nix-serve-ng;
          secretKeyFile = config.age.secrets.nix_store_signing_key.path;
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
              let
                buildKey = builtins.readFile (self + "/.secrets/users/nix-remote-build/id_ed25519.pub");
                userSshKeys = lib.concatMap (u: u.sshKeys or [ ]) resolved-users;
              in
              lib.map (key: ''command="nix-store --serve --write",restrict '' + key) (
                [ buildKey ] ++ userSshKeys
              );
          };
        };
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [ 16893 ];
    };

    age-secrets = {
      # nix-serve now runs under systemd DynamicUser and consumes the key via
      # LoadCredential (read as root), so there is no static nix-serve user to
      # own the secret — keep it root-owned and root-readable.
      age.secrets.nix_store_signing_key = {
        generator.script = "binary-cache-key";
        owner = "root";
        mode = "0400";
      };
    };
  };
}
