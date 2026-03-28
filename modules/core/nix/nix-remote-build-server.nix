{ rootPath, ... }:
{
  features.nix-remote-build-server.system =
    {
      config,
      secrets,
      pkgs,
      lib,
      flakeLib,
      users,
      ...
    }:
    {
      # Secret definitions moved to provides.secrets

      services.nix-serve = {
        enable = true;
        package = pkgs.nix-serve-ng;
        secretKeyFile = secrets.nix_store_signing_key;
        port = 16893;
        openFirewall = true;
      };

      nix.settings = {
        trusted-users = [ "nix-remote-build" ];
        allowed-users = [ "nix-remote-build" ];
      };

      users = {
        groups.nix-remote-build = {
          name = "nix-remote-build";
        };

        users.nix-remote-build = {
          group = "nix-remote-build";
          isSystemUser = true;
          useDefaultShell = true;
          description = "nix-remote-build";
          openssh.authorizedKeys.keys =
            lib.map (key: ''command="nix-store --serve --write",restrict '' + key)
              (
                [ (builtins.readFile (rootPath + "/.secrets/users/nix-remote-build/id_ed25519.pub")) ]
                ++ flakeLib.users.getSshKeysForGroup users "wheel"
              );
        };
      };
    };

  features.nix-remote-build-server.provides.secrets.os = {
    age.secrets.nix_store_signing_key = {
      generator.script = "binary-cache-key";
      owner = "nix-serve";
      mode = "0400";
    };
  };

  features.nix-remote-build-server.provides.firewall.os = {
    networking.firewall.allowedTCPPorts = [ 16893 ];
  };
}
