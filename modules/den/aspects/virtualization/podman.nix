{ den, ... }:
{
  den.aspects.virtualization.podman = {
    nixos =
      {
        config,
        host,
        lib,
        pkgs,
        settings,
        ...
      }:
      let
        zfsEnabled = host.hasFeature "zfs-root";
        btrfsEnabled = host.hasFeature "btrfs-root";
        cacheRoot = config.environment.persistence."/cache".persistentStoragePath;
      in
      {
        environment.systemPackages = [
          pkgs.dive
          pkgs.podman-compose
          pkgs.podman-tui
          pkgs.passt
          pkgs.gomanagedocker
          pkgs.fuse-overlayfs
        ];

        virtualisation = {
          containers.enable = true;
          oci-containers.backend = "podman";
          podman = {
            enable = true;
            extraPackages = lib.optional zfsEnabled config.boot.zfs.package;
            autoPrune = {
              enable = true;
              flags = [ "--all" ];
              dates = "weekly";
            };
            defaultNetwork.settings.dns_enabled = true;
            dockerCompat = true;
            dockerSocket.enable = true;
          };

          containers.storage.settings.storage = lib.mkMerge [
            {
              runroot = "/run/containers/storage";
              graphroot = "/var/lib/containers/storage";
            }

            (lib.mkIf (settings.impermanence.enable or false) {
              rootless_storage_path = "${cacheRoot}$HOME/.local/share/containers/storage";
            })

            (lib.mkIf zfsEnabled {
              driver = "zfs";
              options.zfs = {
                fsname = "zroot/containers";
                mountopt = "nodev";
              };
            })

            (lib.mkIf btrfsEnabled {
              driver = "btrfs";
            })

            (lib.mkIf (!zfsEnabled && !btrfsEnabled) {
              driver = "overlay";
              options.overlay.mountopt = "nodev,metacopy=on";
              options.mount_program = lib.getExe pkgs.fuse-overlayfs;
            })
          ];
        };

        systemd.user.extraConfig = ''
          DefaultEnvironment="PATH=/run/current-system/sw/bin:/run/wrappers/bin:${lib.makeBinPath [ pkgs.bash ]}"
        '';

        boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
      };

    provides.impermanence = {
      nixos = _: {
        environment.persistence."/cache".directories = [
          "/var/lib/cni"
          "/var/lib/containers"
        ];
      };
      homeManager = {
        home.persistence."/cache".directories = [
          ".local/share/containers"
        ];
      };
    };
  };
}
