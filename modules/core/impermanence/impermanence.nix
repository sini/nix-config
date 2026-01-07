{ inputs, ... }:
{
  # Impermanence Module
  # ===================
  # This module implements an impermanent root filesystem pattern where the root
  # and optionally home directories are reset to a clean state on every boot.
  # State that needs to persist is explicitly declared and stored in separate
  # persistent directories (/persist and /cache).
  #
  # Architecture:
  # - /persist: Long-term persistent data (configuration, SSH keys, user files)
  # - /cache: Semi-persistent data that can be deleted (cache, downloads)
  # - /: Ephemeral root that gets wiped on boot, returning to a blank state
  #
  # This approach provides:
  # - Declarative system state (only what's explicitly saved persists)
  # - Clean boots without accumulated cruft
  # - Better security (temporary files are truly temporary)
  # - Easier recovery (rollback to last boot snapshot)

  # Notes: We provide BTRFS and ZFS implementations. ZFS is preferred due to its
  # superior snapshot and rollback capabilities. BTRFS implementation is more
  # complex due to subvolume management.
  #
  # All of our systems are migrating to ZFS, so I provide BTRFS for example only
  # and legacy support. New systems should use ZFS so we can easily manage and backup
  # snapshots. BTRFS doesn't support snapshot on shutdown.

  flake.features.impermanence = {
    nixos =
      {
        lib,
        config,
        pkgs,
        activeFeatures,
        ...
      }:
      with lib;
      with builtins;
      let
        # Check which filesystem is in use to enable appropriate rollback mechanisms
        zfsEnabled = lib.elem "zfs" activeFeatures;
        btrfsEnabled = lib.elem "btrfs" activeFeatures;
        legacyFs = lib.elem "disk-single" activeFeatures;
        # Note: Legacy disk-single feature is used to detect legacy disk configuration modules.
        # This disk configuration only supports BTRFS, and only provided a /persist subvolume and is being phased out.
        # These disks also didn't take initial snapshots for rollback, so root/home rollback won't work with legacyFs either...
        # We will re-image these hosts and remove this ASAP.
        cfg = config.impermanence;
      in
      {
        imports = [
          inputs.impermanence.nixosModules.impermanence
        ];

        options.impermanence = with lib.types; {
          enable = lib.mkOption {
            type = types.bool;
            default = true;
            description = "Enable impermanence features.";
          };
          wipeRootOnBoot = lib.mkOption {
            type = types.bool;
            default = true;
            description = ''
              Enable root rollback on boot. When enabled, the root filesystem
              is reset to a blank snapshot on every boot, effectively wiping
              all state not stored in /persist or /cache.
            '';
          };
          wipeHomeOnBoot = lib.mkOption {
            type = types.bool;
            default = false;
            description = ''
              Enable home rollback on boot. When enabled, /home is reset to a
              blank snapshot on every boot. Use with caution - ensure all
              important user data is declared in persistence directories.
            '';
          };
          ignorePaths = lib.mkOption {
            type = types.listOf types.str;
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

        config = {

          # Persistence Configuration
          # =========================
          # Define what files and directories should persist across reboots.
          # The impermanence module uses bind mounts to overlay persistent
          # directories onto the ephemeral root filesystem.
          #
          # hideMounts = true: Hides the bind mounts from 'df' and 'mount' output
          # to reduce clutter while maintaining functionality.

          system.activationScripts."var-lib-private-perms" = lib.mkIf config.impermanence.enable {
            # Ensure the systemd private directory has the correct permissions set
            # Also verify /var/lib
            #
            # Impermanence will create the outer parent directory and set wrong permissions for it if any
            # path within is persisted, thus we need to set it back to what systemd expects
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
            # /cache: Semi-persistent storage
            # ----------------------------------
            # Data here persists across reboots but is considered "safe to delete".
            # Typically used for caches, temporary state, and system-generated data.
            "/cache" = {
              enable = cfg.enable;
              # TODO: Remove once we kill legacyFs support
              # Mount in persist/cache if using legacy disk config
              persistentStoragePath = if legacyFs then "/persist/cache" else "/cache";
              hideMounts = true;
              directories = [
                "/var/lib/nixos" # NixOS state (user/group IDs, etc.)
                "/var/tmp" # Temporary files that should survive reboots
                "/srv" # Service data directory
              ];
            };

            # /persist: Long-term persistent storage
            # --------------------------------------
            # Critical system state and configuration that must survive reboots.
            # Only essential files should be here to maintain system declarativeness.
            "/persist" = {
              enable = cfg.enable;
              hideMounts = true;
              directories = [ ];
              files = [
                # System identity - needed for consistent machine identification
                "/etc/machine-id"
                # ZFS pool cache - speeds up ZFS pool import on boot
                "/etc/zfs/zpool.cache"
                # Hardware clock drift correction - maintains accurate time
                "/etc/adjtime"

                "/root/.bash_history"
                # SSH host keys - CRITICAL for remote access and agenix secret decryption
                # Without these, the host would generate new keys on every boot:
                # - Breaking SSH host verification (MITM warnings)
                # - Breaking agenix (secrets encrypted for old host key)
                # - Breaking remote management and deployment
                "/etc/ssh/ssh_host_ed25519_key"
                "/etc/ssh/ssh_host_ed25519_key.pub"
                "/etc/ssh/ssh_host_rsa_key"
                "/etc/ssh/ssh_host_rsa_key.pub"
              ];
            };
          };

          # Ignore paths for zfs-diff and other tooling
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

          # Boot Rollback Services
          # ======================
          # These systemd services run during early boot (initrd stage) to reset
          # the root and/or home filesystems to a clean state. This is the core
          # of the impermanence system.
          #
          # The services are carefully ordered to run:
          # 1. After filesystem/encryption is available
          # 2. Before the filesystem is mounted for normal use
          # This ensures a clean slate before the system starts.

          boot.initrd.systemd.services =
            lib.optionalAttrs cfg.wipeRootOnBoot {
              # ZFS Root Rollback
              # -----------------
              # Rollback to the @empty snapshot created during initial setup.
              # The '-r' flag recursively rolls back any child datasets.
              rollback-zfs-root = lib.mkIf zfsEnabled {
                description = "Rollback ZFS root dataset to a pristine state";
                wantedBy = [ "initrd.target" ];
                after = [ "zfs-import-zroot.service" ]; # Wait for ZFS pool import
                before = [ "sysroot.mount" ]; # Must complete before root is mounted
                path = [ config.boot.zfs.package ];
                unitConfig.DefaultDependencies = "no";
                serviceConfig.Type = "oneshot";
                script = ''
                  zfs rollback -r zroot/local/root@empty && echo "rollback complete"
                '';
              };

              # BTRFS Root Rollback
              # -------------------
              # BTRFS rollback is more complex than ZFS because:
              # 1. We need to mount the BTRFS volume to access subvolumes
              # 2. Nested subvolumes must be deleted before parent subvolume
              # 3. We restore from a /root-blank snapshot to /root
              rollback-btrfs-root = lib.mkIf btrfsEnabled {
                description = "Rollback BTRFS root subvolume to a pristine state";
                wantedBy = [ "initrd.target" ];
                # Wait for LUKS decryption (via TPM or passphrase)
                after = [ "systemd-cryptsetup@cryptroot.service" ];
                # Must complete before root filesystem is mounted for use
                before = [ "sysroot.mount" ];
                unitConfig.DefaultDependencies = "no";
                serviceConfig.Type = "oneshot";
                script = ''
                  mkdir -p /mnt

                  # Mount the BTRFS root volume (not a subvolume) to access all subvolumes
                  mount -o subvol=/ /dev/mapper/cryptroot /mnt
                  btrfs subvolume list -o /mnt/root

                  # BTRFS requires deleting nested subvolumes before parent subvolume.
                  # Systemd automatically creates subvolumes for containers:
                  # - /var/lib/portables (systemd-portabled)
                  # - /var/lib/machines (systemd-nspawn containers)
                  # These must be deleted first before we can delete /root.
                  btrfs subvolume list -o /mnt/root |
                  cut -f9 -d' ' |
                  while read subvolume; do
                    echo "deleting /$subvolume subvolume..."
                    btrfs subvolume delete "/mnt/$subvolume"
                  done &&
                  echo "deleting /root subvolume..." &&
                  btrfs subvolume delete /mnt/root

                  # Restore from the blank snapshot created during initial setup
                  echo "restoring blank /root subvolume..."
                  btrfs subvolume snapshot /mnt/root-blank /mnt/root

                  # Clean up: unmount and continue boot process
                  umount /mnt
                '';
              };
            }
            // lib.optionalAttrs cfg.wipeHomeOnBoot {
              # Home Directory Rollback
              # -----------------------
              # Similar to root rollback, but for /home. Use with caution!
              # Ensure all important user data is declared in persistence.

              # ZFS Home Rollback
              rollback-zfs-home = lib.mkIf zfsEnabled {
                description = "Rollback ZFS home dataset to a pristine state";
                wantedBy = [ "initrd.target" ];
                after = [ "zfs-import-zroot.service" ];
                before = [ "-.mount" ];
                path = [ config.boot.zfs.package ];
                unitConfig.DefaultDependencies = "no";
                serviceConfig.Type = "oneshot";
                script = ''
                  zfs rollback -r zroot/local/home@empty && echo "rollback complete"
                '';
              };

              # BTRFS Home Rollback
              rollback-btrfs-home = lib.mkIf btrfsEnabled {
                description = "Rollback BTRFS home subvolume to a pristine state";
                wantedBy = [ "initrd.target" ];
                after = [ "systemd-cryptsetup@cryptroot.service" ];
                before = [ "home.mount" ];
                unitConfig.DefaultDependencies = "no";
                serviceConfig.Type = "oneshot";
                script = ''
                  mkdir -p /mnt
                  mount -o subvol=/ /dev/mapper/cryptroot /mnt

                  # Recursively delete all nested subvolumes first
                  btrfs subvolume list -o /mnt/home |
                  cut -f9 -d' ' |
                  while read subvolume; do
                    echo "deleting /$subvolume subvolume..."
                    btrfs subvolume delete "/mnt/$subvolume"
                  done &&
                  echo "deleting /home subvolume..." &&
                  btrfs subvolume delete /mnt/home

                  # Restore from blank snapshot
                  echo "restoring blank /home subvolume..."
                  btrfs subvolume snapshot /mnt/home-blank /mnt/home

                  umount /mnt
                '';
              };
            };

          systemd = lib.mkIf (zfsEnabled && cfg.wipeRootOnBoot && cfg.wipeHomeOnBoot) {
            # ZFS Shutdown Hook
            # =================
            # Before shutdown, create recovery snapshots and rollback to empty state.
            # This ensures:
            # 1. A @lastboot snapshot exists for emergency recovery
            # 2. The system state is already clean before reboot
            # 3. ZFS pool is properly synced to disk
            #
            # Recovery process: If needed, you can restore the last boot state with:
            #   zfs rollback zroot/local/root@lastboot
            shutdownRamfs.contents."/etc/systemd/system-shutdown/zpool".source = lib.mkForce (
              pkgs.writeShellScript "zpool-sync-shutdown" ''
                # Remove existing lastboot snapshots if they exist
                ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/root@lastboot" 2>/dev/null || true
                ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/home@lastboot" 2>/dev/null || true

                # Take new lastboot snapshots for recovery
                ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/root@lastboot"
                ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/home@lastboot"

                # Rollback to empty state (optimization: start next boot clean)
                ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/root@empty"
                ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/home@empty"

                # Sync the pool before shutdown to ensure data integrity
                exec ${config.boot.zfs.package}/bin/zpool sync
              ''
            );

            # Ensure zfs binary is available in the shutdown ramfs
            shutdownRamfs.storePaths = [ "${config.boot.zfs.package}/bin/zfs" ];
          };
        };
      };

    # Home Manager Integration
    # ========================
    # Configure per-user persistence using home-manager's impermanence module.
    # This manages user-level files and directories that should persist.
    #
    # The configuration is split between:
    # - /persist: Important user data (documents, SSH keys, GPG keys)
    # - /cache: Temporary user data (downloads, caches)
    home = {
      home.persistence = {
        # /persist: Long-term user data
        # -----------------------------
        # Files and directories here are backed up and considered important.
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

        # /cache: Temporary user data
        # ------------------------------
        # Data that's useful to keep but can be regenerated or is not critical.
        "/cache" = {
          directories = [
            # Regenerable data
            "Downloads" # Downloads folder
            ".local/share/direnv" # Direnv cache (can be rebuilt)
            ".local/share/nix" # Nix settins and such
            ".cache" # Application caches (can be regenerated)
          ];
        };
      };
    };
  };
}
