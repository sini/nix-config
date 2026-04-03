# Typed host schema extensions for den aspects.
# Aspects declare their settings here; hosts set them with proper types and defaults.
# Accessed by aspects via host.settings.<aspect-name>.<option>.
{ lib, ... }:
{
  den.schema.host = _: {
    options = {
      # Host-level access control
      system-access-groups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Unix groups that grant login access to this host";
      };

      # Per-aspect settings namespace
      settings = {
        linux-kernel = {
          channel = lib.mkOption {
            type = lib.types.enum [
              "lts"
              "latest"
            ];
            default = "latest";
            description = "CachyOS kernel release channel";
          };
          optimization = lib.mkOption {
            type = lib.types.enum [
              "server"
              "zen4"
              "x86_64-v4"
            ];
            default = "server";
            description = "CachyOS kernel optimization target";
          };
        };

        impermanence = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable impermanence features";
          };
          wipeRootOnBoot = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Reset root filesystem to blank snapshot on every boot";
          };
          wipeHomeOnBoot = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Reset home filesystem to blank snapshot on every boot";
          };
        };

        tailscale = {
          openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to open the firewall for Tailscale";
          };
          extraUpFlags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Additional flags to pass to tailscale up";
          };
          extraDaemonFlags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "--no-logs-no-support" ];
            description = "Additional flags for the tailscale daemon";
          };
          useNftables = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Force tailscaled to use nftables instead of iptables-compat";
          };
        };

        zfs-disk-single = {
          device_id = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Disk device path for ZFS. If null, auto-detected from facter.";
          };
        };

        btrfs-disk-single = {
          device_id = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Disk device path for BTRFS. If null, auto-detected from facter.";
          };
          swap_size = lib.mkOption {
            type = lib.types.str;
            default = "0";
            description = "Swap partition size (e.g., '8G'). '0' disables swap.";
          };
        };

        network-manager = {
          wifi-backend = lib.mkOption {
            type = lib.types.enum [
              "wpa_supplicant"
              "iwd"
            ];
            default = "wpa_supplicant";
            description = "WiFi backend for NetworkManager";
          };
        };

        ceph-device-allocation = {
          device = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Full device path for Ceph OSD (e.g., /dev/disk/by-id/nvme-...).";
          };
        };

        xfs-disk-longhorn = {
          device_id = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Longhorn data drive full device path (e.g., /dev/disk/by-id/nvme-...).";
          };
          mountPoint = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/longhorn";
            description = "Mount point for the Longhorn data drive.";
          };
        };
      };
    };
  };
}
