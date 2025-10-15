{
  flake.features.podman.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        dive # look into docker image layers
        podman-compose
        podman-tui # Terminal mgmt UI for Podman
        passt # For Pasta rootless networking
        gomanagedocker
      ];

      virtualisation = {
        containers.enable = true;
        oci-containers.backend = "podman";
        podman = {
          enable = true;

          # prune images and containers periodically
          autoPrune = {
            enable = true;
            flags = [ "--all" ];
            dates = "weekly";
          };

          defaultNetwork.settings = {
            dns_enabled = true;
            driver = "bridge";
            name = builtins.head config.hardware.networking.bridges;
          };
          dockerCompat = true;
          dockerSocket.enable = true;
        };

        containers.storage.settings = {
          storage = {
            driver = "btrfs";
            runroot = "/run/containers/storage";
            graphroot = "/var/lib/containers/storage";
            options.overlay.mountopt = "nodev,metacopy=on";
          }; # storage
        };
      };

      networking.networkmanager.unmanaged = [
        "interface-name:veth*"
        "interface-name:podman*"
        "interface-name:cni*"
      ];

      # Add 'newuidmap' and 'sh' to the PATH for users' Systemd units.
      # Required for Rootless podman.
      systemd.user.extraConfig = ''
        DefaultEnvironment="PATH=/run/current-system/sw/bin:/run/wrappers/bin:${lib.makeBinPath [ pkgs.bash ]}"
      '';

      # Allow non-root containers to access lower port numbers
      boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
    };
}
