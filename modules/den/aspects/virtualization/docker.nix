{ lib, ... }:
let
  resolvers = import ../core/network/_resolvers.nix { inherit lib; };
in
{
  den.aspects.virtualization.docker = {
    nixos =
      {
        dns-resolvers,
        environment,
        pkgs,
        ...
      }:
      {
        environment.systemPackages = [
          pkgs.dive
          pkgs.docker-buildx
          pkgs.docker-compose
          pkgs.gomanagedocker
        ];

        virtualisation = {
          containers.enable = true;
          oci-containers.backend = "docker";
          docker = {
            enable = true;
            package = pkgs.docker;
            listenOptions = [
              "/var/run/docker.sock"
              "/run/docker.sock"
            ];
            enableOnBoot = true;
            logDriver = "journald";

            daemon.settings = {
              # Containers resolve as the host's links do, in plain DNS.
              dns = resolvers.plainResolversFor environment dns-resolvers;
              dns-opts = [ "ndots:0" ];
              features = {
                buildkit = true;
              };
            };

            autoPrune = {
              enable = true;
              flags = [ "--all" ];
              dates = "weekly";
            };
          };
        };

        networking.firewall.trustedInterfaces = [ "docker0" ];
      };

    persist = {
      directories = [
        "/var/lib/docker"
        "/var/lib/cni"
        "/var/lib/containers"
      ];
    };
  };
}
