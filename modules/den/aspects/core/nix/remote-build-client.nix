# Remote build client -- distributes builds to other hosts.
# Consumes nix-builders quirk data emitted by roles.nix-builder.
{
  self,
  lib,
  den,
  ...
}:
let
  # The hosts that carry `name` as a microvm guest.
  parentsOf =
    name:
    lib.concatMap (hs: lib.attrNames (lib.filterAttrs (_: h: (h.guests or { }) ? ${name}) hs)) (
      lib.attrValues den.hosts
    );
in
{
  den.aspects.core.nix.remote-build-client = {
    nixos =
      {
        config,
        nix-builders,
        host,
        ...
      }:
      let
        # A persistent-store guest never builds on, or substitutes from, its own host: the
        # output lands in the guest's lower layer, where a negative overlay dentry the guest
        # cached for that path hides it (docs/microvm-persistent-store.md §4).
        excluded = lib.optionals (host.microvm.persistentStore.enable or false) (parentsOf host.name);
        remoteBuilders = lib.filter (
          b: b.hostname != host.name && !(lib.elem b.hostname excluded) && b.system == host.system
        ) nix-builders;
      in
      {
        nix = {
          distributedBuilds = true;

          buildMachines = map (builder: {
            hostName = builder.hostname;
            systems = [ builder.system ];
            inherit (builder) maxJobs speedFactor supportedFeatures;
            mandatoryFeatures = [ ];
            sshUser = "nix-remote-build";
            sshKey = config.age.secrets.nix-remote-build-user-key.path;
          }) remoteBuilders;

          settings = {
            builders-use-substitutes = true;
            substituters = map (b: "http://${b.hostname}:16893") remoteBuilders;
            trusted-public-keys = lib.concatMap (
              b:
              lib.optional (b.secretPath != null) (
                builtins.readFile (b.secretPath + "/generated/nix_store_signing_key.pub")
              )
            ) remoteBuilders;
          };
        };
      };

    age-secrets = {
      age.secrets.nix-remote-build-user-key = {
        rekeyFile = self + "/.secrets/users/nix-remote-build/id_ed25519.age";
        mode = "600";
        generator.script = "shared-ssh-key";
      };
    };
  };
}
