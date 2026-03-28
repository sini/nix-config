{
  rootPath,
  ...
}:
{
  features.nix.os =
    {
      config,
      flakeLib,
      lib,
      host,
      ...
    }:
    let
      builders = flakeLib.host-utils.findHostsWithFeature "nix-builder";
      remoteBuilders = lib.filterAttrs (
        hostname: builder: (hostname != config.networking.hostName) && (host.system == builder.system)
      ) builders;
      localBuildSpeed = host.remoteBuildSpeed;
    in
    {
      # Secret definitions moved to provides.secrets

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
              _hostname: builderHost:
              (builtins.readFile (builderHost.secretPath + "/generated/nix_store_signing_key.pub"))
            ) remoteBuilders;
          };

        distributedBuilds = true;
      };
    };

  features.nix.provides.secrets.os = {
    age.secrets.nix-remote-build-user-key = {
      rekeyFile = rootPath + "/.secrets/users/nix-remote-build/id_ed25519.age";
      mode = "600";
      generator.script = "shared-ssh-key";
    };
  };
}
