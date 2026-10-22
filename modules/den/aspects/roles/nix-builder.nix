{ den, lib, ... }:
{
  den.aspects.roles.nix-builder = {
    includes = [
      den.aspects.services.nix.remote-build-server
    ];

    # Capacity this host offers remote-build clients (the bgp pattern: the aspect declares the
    # option, the host file sets it).
    settings = {
      maxJobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4;
        description = "Concurrent builds this host accepts from remote-build clients";
      };
      speedFactor = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = "Relative preference remote-build clients give this host";
      };
    };

    nix-builders =
      { host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit (host) system;
        inherit (host) secretPath;
        inherit (host.settings.roles.nix-builder) maxJobs speedFactor;
      };
  };
}
