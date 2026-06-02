# Remote build client -- distributes builds to other hosts.
# Consumes nix-builders quirk data emitted by roles.nix-builder.
{ self, lib, ... }:
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
        remoteBuilders = lib.filter (b: b.hostname != host.name && b.system == host.system) nix-builders;
      in
      {
        nix = {
          distributedBuilds = true;

          buildMachines = map (builder: {
            hostName = builder.hostname;
            systems = [ builder.system ];
            maxJobs = 8;
            speedFactor = 1;
            supportedFeatures = [
              "benchmark"
              "big-parallel"
              "kvm"
              "nixos-test"
            ];
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
