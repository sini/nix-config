{
  den,
  self,
  config,
  lib,
  rootPath,
  ...
}:
let
  inherit (self.lib.users) resolveUsers getSshKeysForGroup;
  canonicalUsers = config.users or { };
  groupDefs = config.groups or { };
in
{
  den.aspects.nix-remote-build-server = {
    includes = lib.attrValues den.aspects.nix-remote-build-server._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          hostOptions = {
            hostname = host.name;
            system-access-groups = host.system-access-groups or [ ];
            users = host.users or { };
          };
          resolvedUsers = resolveUsers lib canonicalUsers host.environment hostOptions groupDefs;
        in
        {
          nixos =
            {
              config,
              pkgs,
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
                    lib.map (key: ''command="nix-store --serve --write",restrict '' + key)
                      (
                        [ (builtins.readFile (rootPath + "/.secrets/users/nix-remote-build/id_ed25519.pub")) ]
                        ++ getSshKeysForGroup resolvedUsers "wheel"
                      );
                };
              };
            };
        }
      );

      secrets = den.lib.perHost {
        secrets.nix_store_signing_key = {
          generator.script = "binary-cache-key";
          owner = "nix-serve";
          mode = "0400";
        };
      };

      firewall = den.lib.perHost {
        firewall.allowedTCPPorts = [ 16893 ];
      };
    };
  };
}
