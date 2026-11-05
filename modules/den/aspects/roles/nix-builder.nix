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
      supportedFeatures = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        description = "System features this host builds, for its own nix and its remote-build clients";
      };
    };

    # Forced: nixpkgs defines its default list in config, so a plain definition would add to it.
    nixos =
      { host, ... }:
      {
        nix.settings.system-features = lib.mkForce host.settings.roles.nix-builder.supportedFeatures;
      };

    nix-builders =
      { host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit (host) system;
        inherit (host) secretPath;
        inherit (host.settings.roles.nix-builder) maxJobs speedFactor supportedFeatures;
      };
  };
}
