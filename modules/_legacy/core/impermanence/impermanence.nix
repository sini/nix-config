{ inputs, lib, ... }:
{
  # Impermanence Module
  # ===================
  # Implements an impermanent root filesystem where root and home directories are
  # reset to a clean state on every boot. Only explicitly declared state persists.
  #
  # Architecture:
  # - /persist: Long-term data (configs, SSH keys, user files)
  # - /cache: Semi-persistent data (caches, downloads)
  # - /: Ephemeral root wiped on boot
  #
  # Benefits: Declarative state, clean boots, better security, easy recovery
  #
  # Filesystem-specific rollback implementations:
  # - impermanence-zfs.nix: ZFS support (preferred)
  # - impermanence-btrfs.nix: BTRFS support (legacy)

  features.impermanence = {
    collectsProviders = [ "impermanence" ];

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

    # Cross-platform option for ignorePaths accumulator (other modules contribute to this)
    system =
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

      };

    linux =
      {
        lib,
        settings,
        ...
      }:
      let
        cfg = settings.impermanence;
      in
      {
        imports = [
          inputs.impermanence.nixosModules.impermanence
        ];

        # Persistence Configuration
        # =========================
        # Defines files and directories that persist across reboots via bind mounts.
        # hideMounts = true: Hides bind mounts from 'df' and 'mount' output.

        system.activationScripts."var-lib-private-perms" = lib.mkIf cfg.enable {
          # Fix /var/lib and /var/lib/private permissions after impermanence creates them.
          # Impermanence sets incorrect permissions on parent directories.
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
            inherit (cfg) enable;
            persistentStoragePath = "/cache";
            hideMounts = true;
            directories = [
              "/var/lib/nixos" # NixOS state (user/group IDs)
              "/var/tmp" # Temporary files surviving reboots
              "/srv" # Service data
            ];
          };

          # /persist: Critical long-term storage (essential system state)
          "/persist" = {
            inherit (cfg) enable;
            hideMounts = true;
            directories = [ ];
            files = [
              "/etc/machine-id" # System identity
              "/etc/zfs/zpool.cache" # ZFS pool cache (faster import)
              "/etc/adjtime" # Hardware clock drift correction
              "/root/.bash_history"

              # SSH host keys - CRITICAL for agenix decryption and remote access
              "/etc/ssh/ssh_host_ed25519_key"
              "/etc/ssh/ssh_host_ed25519_key.pub"
              "/etc/ssh/ssh_host_rsa_key"
              "/etc/ssh/ssh_host_rsa_key.pub"
            ];
          };
        };

        # Paths ignored by persistence diff tooling (system-managed files)
        impermanence.ignorePaths = [
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

        # Filesystem-specific rollback: impermanence-{zfs,btrfs}.nix
      };

    # Home Manager Integration
    # ========================
    # Per-user persistence configuration for files and directories.
    # - /persist: Important user data (backed up)
    # - /cache: Temporary user data (regenerable)
    home = {
      home.persistence = {
        # /persist: Long-term user data
        "/persist" = {
          directories = [
            # XDG user directories - standard user folders
            "Desktop"
            "Documents"
            "Music"
            "Pictures"
            "Public"
            "Templates"
            "Videos"

            # Security/Authentication
            {
              directory = ".ssh"; # SSH keys and known hosts
              mode = "0700";
            }
            {
              directory = ".local/share/keyrings"; # Keyring/password storage
              mode = "0700";
            }
          ];
        };

        # /cache: Temporary user data (regenerable)
        "/cache" = {
          directories = [
            "Downloads"
            ".local/share/direnv" # Direnv cache
            ".local/share/nix" # Nix settings
            ".cache" # Application caches
          ];
        };
      };
    };
  };
}
