{
  flake.features.network-boot.nixos =
    {
      config,
      lib,
      activeFeatures,
      pkgs,
      ...
    }:
    let
      zfsEnabled = lib.elem "zfs" activeFeatures;
      nfsServer = "10.10.10.10";
      hostname = config.networking.hostName;
    in
    {
      boot = {
        supportedFilesystems = [ "nfs" ];
        initrd = {
          availableKernelModules = [
            "r8169" # Host: surge, burst, pulse
            "mlx4_core"
            "mlx4_en" # Hosts: uplink, cortex
            "bridge"
            "bonding"
            "8021q"
            "nfsv4"
          ];

          systemd = {
            inherit (config.systemd) network;
            # users.root.shell = "/bin/systemd-tty-ask-password-agent";
            extraBin = {
              "mount.nfs" = "${pkgs.nfs-utils}/bin/mount.nfs";
              "mount.nfs4" = "${pkgs.nfs-utils}/bin/mount.nfs4";
            };
            services.zfs-load-nfs-key = lib.mkIf zfsEnabled {
              description = "Load ZFS key from NFS if available";
              wantedBy = [ "initrd.target" ];
              before = [
                "zfs-import-zroot.service"
                "systemd-ask-password-console.service"
              ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };

              # Based on https://github.com/NixOS/nixpkgs/blob/d792a6e0cd4ba35c90ea787b717d72410f56dc40/nixos/modules/tasks/filesystems/zfs.nix
              # Wait for the pool to be ready before adding the keys...
              script = ''
                poolReady() {
                  pool="zroot"
                  state="$(${config.boot.zfs.package}/sbin/zpool import -d "/dev/disk/by-id/" 2>/dev/null | "${pkgs.gawk}/bin/awk" "/pool: $pool/ { found = 1 }; /state:/ { if (found == 1) { print \$2; exit } }; END { if (found == 0) { print \"MISSING\" } }")"
                  if [[ "$state" = "ONLINE" ]]; then
                    return 0
                  else
                    echo "Pool $pool in state $state, waiting"
                    return 1
                  fi
                }
                poolImported() {
                  pool="zroot"
                  "${config.boot.zfs.package}/sbin/zpool" list "$pool" >/dev/null 2>/dev/null
                }
                poolImport() {
                  pool="zroot"
                  # shellcheck disable=SC2086
                  "${config.boot.zfs.package}/sbin/zpool" import -d "/dev/disk/by-id/" -N $ZFS_FORCE "$pool"
                }
                if ! poolImported "zroot"; then
                  echo -n "importing ZFS pool \"zroot\"..."
                  # Loop across the import until it succeeds, because the devices needed may not be discovered yet.
                  for _ in $(seq 1 60); do
                    poolReady "zroot" && poolImport "zroot" && break
                    sleep 1
                  done
                  poolImported "zroot" || poolImport "zroot"  # Try one last time, e.g. to import a degraded pool.
                fi
                if poolImported "zroot"; then
                  echo "Sleeping 5 seconds to wait for network..."
                  sleep 5
                  # Try NFS mount with timeout
                  mkdir -p /mnt/nfs-keys
                  if mount -t nfs -o ro,soft,timeo=50,retrans=1 ${nfsServer}:/volume2/keys /mnt/nfs-keys 2>/dev/null; then
                    echo "Mount succeeded"
                    if [ -f /mnt/nfs-keys/${hostname}.key ]; then
                      echo "Found key, loading..."
                      "${config.boot.zfs.package}/sbin/zfs" load-key -L file:///mnt/nfs-keys/${hostname}.key zroot
                    fi
                    umount /mnt/nfs-keys
                  fi
                  # If NFS fails, boot will fall back to password prompt

                  echo "Successfully imported zroot"
                else
                  exit 1
                fi
              '';
            };
          };

          network = {
            enable = true;
            ssh = {
              enable = true;
              port = 22;
              authorizedKeys =
                with lib;
                concatLists (
                  mapAttrsToList (
                    _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
                  ) config.users.users
                );
              hostKeys = [
                config.age.secrets.initrd_host_ed25519_key.path
              ];
            };
          };
        };
      };
    };
}
