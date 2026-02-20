{ rootPath, ... }:
{
  flake.features.nix-remote-build-server.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      age.secrets.nix_store_signing_key = {
        rekeyFile = rootPath + "/.secrets/services/nix-serve/cache-priv-key.pem.age";
        owner = "nix-serve";
        mode = "0400";
      };
      networking.firewall.allowedTCPPorts = [ 16893 ];

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
        groups.nix-remote-build = {
          name = "nix-remote-build";
        };

        users.nix-remote-build = {
          group = "nix-remote-build";
          isSystemUser = true;
          useDefaultShell = true;
          description = "nix-remote-build";
          openssh.authorizedKeys.keys =
            with lib;
            map (key: ''command="nix-store --serve --write",restrict '' + key) (
              [ (builtins.readFile (rootPath + "/.secrets/users/nix-remote-build/id_agenix.pub")) ]
              ++ concatLists (
                mapAttrsToList (
                  _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
                ) config.users.users
              )
            );
        };
      };
    };
}
