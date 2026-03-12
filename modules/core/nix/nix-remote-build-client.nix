{
  self,
  rootPath,
  ...
}:
let
  inherit (self.lib.host-utils) findHostsWithRole;
in
{
  flake.features.nix.nixos =
    {
      config,
      lib,
      hostOptions,
      ...
    }:
    let
      builders = findHostsWithRole "nix-builder";
      localBuildSpeed = hostOptions.remoteBuildSpeed;
    in
    {
      age.secrets.nix-remote-build-user-key = {
        rekeyFile = rootPath + "/.secrets/users/nix-remote-build/id_agenix.age";
        mode = "600";
      };

      nix = {
        buildMachines = lib.mapAttrsToList (hostname: buildHostConfig: {
          hostName = hostname;
          systems = [ buildHostConfig.system ];
          maxJobs = buildHostConfig.remoteBuildJobs;
          speedFactor =
            if buildHostConfig.remoteBuildSpeed < localBuildSpeed then 1 else buildHostConfig.remoteBuildJobs;
          supportedFeatures = lib.optionals (buildHostConfig.remoteBuildSpeed > 1) [
            "benchmark"
            "big-parallel"
            "kvm"
            "nixos-test"
          ];
          mandatoryFeatures = [ ];
          # The server side user to login with
          sshUser = "nix-remote-build";
          # The client side private key for login as sshUser
          sshKey = config.age.secrets.nix-remote-build-user-key.path;
        }) (lib.filterAttrs (hostname: _: hostname != config.networking.hostName) builders);

        settings = {
          builders-use-substitutes = true;
          substituters = lib.mapAttrsToList (hostname: _: "http://${hostname}:16893") (
            lib.filterAttrs (hostname: _: hostname != config.networking.hostName) builders
          );
          trusted-public-keys = [
            (builtins.readFile (rootPath + "/.secrets/services/nix-serve/cache-pub-key.pem"))
          ];
        };

        distributedBuilds = true;
      };
    };
}
