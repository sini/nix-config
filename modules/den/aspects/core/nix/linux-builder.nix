# aarch64-linux build VM on Darwin, so this Mac can build Linux closures for the
# fleet locally instead of relying solely on remote builders.
{
  den.aspects.core.nix.linux-builder = {
    darwin =
      { config, ... }:
      let
        maxJobs = 6;
      in
      {
        nix = {
          distributedBuilds = true;

          buildMachines = [
            {
              hostName = "linux-builder";
              sshUser = "builder";
              inherit maxJobs;
              system = "aarch64-linux";
              protocol = "ssh-ng";
            }
          ];

          linux-builder = {
            enable = true;
            inherit maxJobs;
            ephemeral = true;
            systems = [ "aarch64-linux" ];
            supportedFeatures = [ "kvm" ];
            config.virtualisation = {
              cores = config.nix.linux-builder.maxJobs;
              darwin-builder = {
                diskSize = 30 * 1024;
                memorySize = 8 * 1024;
              };
            };
          };

          settings.builders-use-substitutes = true;
        };

        launchd.daemons.linux-builder.serviceConfig = {
          StandardOutPath = "/var/log/darwin-builder.log";
          StandardErrorPath = "/var/log/darwin-builder.log";
        };
      };
  };
}
