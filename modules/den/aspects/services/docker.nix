_: {
  den.aspects.services.docker = {
    nixos =
      { pkgs, ... }:
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
              dns = [
                "8.8.8.8"
                "1.1.1.1"
              ];
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
