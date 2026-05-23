# Remote build client — distributes builds to other hosts.
# TODO: cross-host discovery (findHostsWithFeature "nix-builder") has no den
# equivalent yet. This is a stub that enables the distributed-builds plumbing;
# the actual builder list must be wired once den supports cross-host queries.
{ self, ... }:
{
  den.aspects.core.nix-remote-build-client = {
    os =
      _:
      {
        nix = {
          distributedBuilds = true;
          settings.builders-use-substitutes = true;
        };
      };

    # Secret for the SSH key used to connect to builders
    nixos = {
      age.secrets.nix-remote-build-user-key = {
        rekeyFile = self + "/.secrets/users/nix-remote-build/id_ed25519.age";
        mode = "600";
        generator.script = "shared-ssh-key";
      };
    };
  };
}
