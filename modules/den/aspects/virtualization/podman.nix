{ den, ... }:
{
  den.aspects.virtualization.podman = {
    includes = [ den.aspects.virtualization.containers ];

    nixos =
      {
        config,
        host,
        lib,
        pkgs,
        ...
      }:
      let
        zfsEnabled = host.hasAspect den.aspects.disk.zfs-disk-single;
        btrfsEnabled = false; # no btrfs aspect ported yet
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

            (lib.mkIf (host.hasAspect den.aspects.core.impermanence) {
              rootless_storage_path = "${cacheRoot}$HOME/.local/share/containers/storage";
            })

            (lib.mkIf zfsEnabled {
              driver = "zfs";
              options.zfs = {
                # The disko-provisioned, tuned dataset backing the graphroot
                # (mounted at /cache/var/lib/containers, bind-exposed at
                # /var/lib/containers). Was the phantom "zroot/containers".
                fsname = "zroot/local/containers";
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

        boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
      };

    cache.directories = [
      "/var/lib/cni"
      "/var/lib/containers"
    ];

    cacheHome.directories = [
      ".local/share/containers"
    ];
  };
}
