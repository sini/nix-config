{ self, rootPath, ... }:
let
  inherit (self.lib.host-utils) findHostsWithRole;
in
{
  flake.features.nix.nixos =
    { config, lib, ... }:
    let
      builders = findHostsWithRole "nix-builder";
    in
    {
      nix = {
        buildMachines = lib.mapAttrsToList (hostname: hostConfig: {
          hostName = hostname;
          systems = [ hostConfig.system ];
          # TODO: I belive maxJobs = "auto" is documented somewhere, but nix-2.2.2
          # and 2.3 fail with unhelpful "error: stoull".
          maxJobs = 4;
          speedFactor = 10;
          supportedFeatures = [
            "benchmark"
            "big-parallel"
            "kvm"
            "nixos-test"
          ];
          mandatoryFeatures = [ ];
          # The server side user to login with
          sshUser = "nix-remote-build";
          # The client side private key for login as sshUser
          sshKey = config.age.secrets.user-nix-remote-build-id_agenix.path;
        }) builders;

        settings = {
          builders-use-substitutes = true;
          substituters = lib.mapAttrsToList (hostname: hostConfig: "http://${hostname}:16893") (
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
