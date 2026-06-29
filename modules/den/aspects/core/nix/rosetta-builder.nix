# x86_64-linux build VM on Darwin via Rosetta, complementing linux-builder so
# this Mac can also produce x86_64-linux closures for the fleet.
{ inputs, ... }:
{
  den.aspects.core.nix.rosetta-builder = {
    darwin = {
      imports = [ inputs.nix-rosetta-builder.darwinModules.default ];

      nix-rosetta-builder = {
        enable = true;
        cores = 4;
      };

      nix = {
        distributedBuilds = true;
        buildMachines = [
          {
            hostName = "rosetta-builder";
            sshUser = "builder";
            maxJobs = 6;
            system = "x86_64-linux";
            protocol = "ssh-ng";
          }
        ];
      };
    };
  };
}
