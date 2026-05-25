# Legacy NFS-based ZFS key loading — replaced by shamir secret sharing
# with TPM+tang in network-boot.nix. Kept for reference.
{
  lib,
  ...
}:
{
  den.aspects.network.nfs-boot = {
    nixos =
      {
        config,
        pkgs,
        ...
      }:
      let
        # TODO: cross-host discovery — hardcoded NFS server address
        nfsServer = "10.10.10.10";
        hostname = config.networking.hostName;
        zfsEnabled = config.boot.supportedFilesystems.zfs or false;
      in
      {
        boot = {
          supportedFilesystems = [ "nfs" ];

          initrd = {
            availableKernelModules = [
              "nfsv4"
            ];

            systemd = {
              inherit (config.systemd) network;

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
                    for _ in $(seq 1 60); do
                      poolReady "zroot" && poolImport "zroot" && break
                      sleep 1
                    done
                    poolImported "zroot" || poolImport "zroot"
                  fi
                  if poolImported "zroot"; then
                    echo "Sleeping 5 seconds to wait for network..."
                    sleep 5
                    mkdir -p /mnt/nfs-keys
                    if mount -t nfs -o ro,soft,timeo=50,retrans=1 ${nfsServer}:/volume2/keys /mnt/nfs-keys 2>/dev/null; then
                      echo "Mount succeeded"
                      if [ -f /mnt/nfs-keys/${hostname}.key ]; then
                        echo "Found key, loading..."
                        "${config.boot.zfs.package}/sbin/zfs" load-key -L file:///mnt/nfs-keys/${hostname}.key zroot
                      fi
                      umount /mnt/nfs-keys
                    fi

                    echo "Successfully imported zroot"
                  else
                    exit 1
                  fi
                '';
              };
            };
          };
        };
      };
  };
}
