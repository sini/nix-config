{
  flake.features.docker.nixos =
    {
      pkgs,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        dive # look into docker image layers
        docker-buildx
        docker-compose
        gomanagedocker
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

          # Fix DNS resolution issues
          daemon.settings = {
            dns = [
              "8.8.8.8"
              "1.1.1.1"
            ];
            dns-opts = [ "ndots:0" ];
            # Enable BuildKit engine for advanced builds and Buildx/Bake
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

      environment.persistence."/persist".directories = [
        "/var/lib/docker"
        "/var/lib/cni"
        "/var/lib/containers"
      ];
    };
}
