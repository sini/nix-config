# Podman: rootless container runtime with ZFS/BTRFS-aware storage.
{ den, lib, ... }:
{
  den.aspects.podman = {
    includes = lib.attrValues den.aspects.podman._;

    _ = {
      config = den.lib.perHost {
        nixos =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            # Check which filesystem is in use to configure appropriate storage driver
            zfsEnabled = config.boot.supportedFilesystems.zfs or false;
            btrfsEnabled = config.boot.supportedFilesystems.btrfs or false;

            # Get the correct persistent storage path for impermanence
            cacheRoot = config.environment.persistence."/cache".persistentStoragePath;
            impermanenceEnabled = config.impermanence.enable or false;
          in
          {
            environment.systemPackages = with pkgs; [
              dive
              podman-compose
              podman-tui
              passt
              gomanagedocker
              fuse-overlayfs
            ];

            virtualisation = {
              containers.enable = true;
              oci-containers.backend = "podman";
              podman = {
                enable = true;

                # ZFS requires zfs package for volume management
                extraPackages = lib.optional zfsEnabled config.boot.zfs.package;

                # prune images and containers periodically
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
                # Common settings for all filesystems
                {
                  runroot = "/run/containers/storage";
                  graphroot = "/var/lib/containers/storage";
                }

                # Rootless storage path for impermanence setups
                (lib.mkIf impermanenceEnabled {
                  rootless_storage_path = "${cacheRoot}$HOME/.local/share/containers/storage";
                })

                # ZFS-specific configuration
                (lib.mkIf zfsEnabled {
                  driver = "zfs";
                  options.zfs = {
                    fsname = "zroot/containers";
                    mountopt = "nodev";
                  };
                })

                # BTRFS-specific configuration
                (lib.mkIf btrfsEnabled {
                  driver = "btrfs";
                })

                # Fallback to overlay driver if no specific filesystem is detected
                (lib.mkIf (!zfsEnabled && !btrfsEnabled) {
                  driver = "overlay";
                  options.overlay.mountopt = "nodev,metacopy=on";
                  options.mount_program = lib.getExe pkgs.fuse-overlayfs;
                })
              ];
            };

            # Add 'newuidmap' and 'sh' to the PATH for users' Systemd units.
            # Required for Rootless podman.
            systemd.user.extraConfig = ''
              DefaultEnvironment="PATH=/run/current-system/sw/bin:/run/wrappers/bin:${lib.makeBinPath [ pkgs.bash ]}"
            '';

            # Allow non-root containers to access lower port numbers
            boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;

          };
      };

      cache = den.lib.perHost {
        nixos = _: {
          environment.persistence."/cache".directories = [
            "/var/lib/cni"
            "/var/lib/containers"
          ];
        };
      };

      cache-home = den.lib.perUser {
        homeManager = {
          home.persistence."/cache".directories = [
            ".local/share/containers"
          ];
        };
      };
    };
  };
}
