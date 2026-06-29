{ den, lib, ... }:
{
  den.hosts.patch = {
    environment = "dev";
    system = "aarch64-darwin";
    channel = "nixpkgs-master";
    system-access-groups = [ "system-access" ];
    system-owner = "sini";

    users.sini = { };
  };

  den.aspects.patch = {
    includes = with den.aspects; [
      roles.default
      roles.dev
      roles.darwin-workstation

      # Build Linux closures locally for the fleet. linux-builder (aarch64-linux,
      # cached image) bootstraps the toolchain; rosetta-builder (x86_64-linux +
      # aarch64-linux) can't be built until a Linux builder is already running,
      # so it's enabled in a second switch once this one is live:
      #   1. switch with linux-builder (below) -> aarch64-linux builder comes up
      #   2. swap to core.nix.rosetta-builder -> its image builds on that builder
      core.nix.linux-builder
    ];

    darwin = {
      # macOS uses uid 501 instead of 1000
      users.users.sini.uid = lib.mkForce 501;

      security.pam.services.sudo_local.touchIdAuth = true;

      # stateVersion is set by the core.nix.stateVersion aspect (darwin = 6).
      system.primaryUser = "sini";
    };
  };
}
