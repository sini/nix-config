{
  self,
  rootPath,
  ...
}:
let
  inherit (self.lib.host-utils) findHostsWithRole;
in
{
  flake.features.nix.system =
    {
      config,
      lib,
      hostOptions,
      ...
    }:
    let
      builders = findHostsWithRole "nix-builder";
      remoteBuilders = lib.filterAttrs (hostname: _: hostname != config.networking.hostName) builders;
      localBuildSpeed = hostOptions.remoteBuildSpeed;
    in
    {
      age.secrets.nix-remote-build-user-key = {
        rekeyFile = rootPath + "/.secrets/users/nix-remote-build/id_ed25519.age";
        mode = "600";
        generator.script = "shared-ssh-key";
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
        }) remoteBuilders;

        settings =

          {
            builders-use-substitutes = true;
            substituters = lib.mapAttrsToList (hostname: _: "http://${hostname}:16893") remoteBuilders;
            trusted-public-keys = lib.mapAttrsToList (
              hostname: _:
              (builtins.readFile (rootPath + "/.secrets/generated/${hostname}/nix_store_signing_key.pub"))
            ) remoteBuilders;
          };

        distributedBuilds = true;
      };
    };
}
