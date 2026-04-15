{
  den,
  inputs,
  lib,
  ...
}:
{
  den.aspects.impermanence = {
    includes = lib.attrValues den.aspects.impermanence._;

    settings = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable impermanence features.";
      };
      wipeRootOnBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable root rollback on boot. When enabled, the root filesystem
          is reset to a blank snapshot on every boot, effectively wiping
          all state not stored in /persist or /cache.
        '';
      };
      wipeHomeOnBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable home rollback on boot. When enabled, /home is reset to a
          blank snapshot on every boot. Use with caution - ensure all
          important user data is declared in persistence directories.
        '';
      };
    };

    _ = {
      # Import the impermanence NixOS module
      nixosModule = den.lib.perHost {
        nixos = {
          imports = [
            inputs.impermanence.nixosModules.impermanence
          ];
        };
      };

      # Cross-platform ignorePaths option declaration
      ignorePathsOption = den.lib.perHost {
        nixos =
          { lib, ... }:
          {
            options.impermanence.ignorePaths = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                A list of absolute paths that should be ignored by persistence tooling.
                These paths are filtered out when using zfs-diff tools.
              '';
              example = [
                "/etc/group"
                "/etc/shadow"
              ];
            };

            config.impermanence.ignorePaths = [
              "/etc/NIXOS"
              "/etc/.clean"
              "/etc/.updated"
              "/etc/.pwd.lock"
              "/var/.updated"
              "/etc/subgid"
              "/etc/subuid"
              "/etc/shadow"
              "/etc/group"
              "/etc/passwd"
              "/root/.nix-channels"
            ];
          };
      };

      # Core persistence configuration (/persist and /cache)
      persistence = den.lib.perHost {
        nixos = _: {
          # Fix /var/lib and /var/lib/private permissions after impermanence creates them
          system.activationScripts."var-lib-private-perms" = {
            deps = [
              "persist-files"
              "createPersistentStorageDirs"
            ];
            text = ''
              mkdir -p /var/lib/private
              chown root:root /var/lib
              chmod 0755 /var/lib
              chown root:root /var/lib/private
              chmod 0700 /var/lib/private
            '';
          };

          environment.persistence = {
            # /cache: Semi-persistent storage (safe to delete)
            "/cache" = {
              persistentStoragePath = "/cache";
              hideMounts = true;
              directories = [
                "/var/lib/nixos"
                "/var/tmp"
                "/srv"
              ];
            };

            # /persist: Critical long-term storage (essential system state)
            "/persist" = {
              hideMounts = true;
              directories = [ ];
              files = [
                "/etc/machine-id"
                "/etc/zfs/zpool.cache"
                "/etc/adjtime"
                "/root/.bash_history"

                # SSH host keys - CRITICAL for agenix decryption and remote access
                "/etc/ssh/ssh_host_ed25519_key"
                "/etc/ssh/ssh_host_ed25519_key.pub"
                "/etc/ssh/ssh_host_rsa_key"
                "/etc/ssh/ssh_host_rsa_key.pub"
              ];
            };
          };
        };
      };

      # Home-manager persistence directories
      homePersistence = den.lib.perUser {
        persistHome.directories = [
          "Desktop"
          "Documents"
          "Music"
          "Pictures"
          "Public"
          "Templates"
          "Videos"
          {
            directory = ".ssh";
            mode = "0700";
          }
          {
            directory = ".local/share/keyrings";
            mode = "0700";
          }
        ];

        cacheHome.directories = [
          "Downloads"
          ".local/share/direnv"
          ".local/share/nix"
          ".cache"
        ];
      };
    };
  };
}
