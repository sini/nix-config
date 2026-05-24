{ den, ... }:
{
  den.aspects.roles.nix-builder = {
    includes = [
      den.aspects.services.nix-remote-build-server
    ];

    nix-builders =
      { host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        system = host.system;
        inherit (host) secretPath;
      };
  };
}
