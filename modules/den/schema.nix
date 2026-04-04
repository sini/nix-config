# Typed host schema extensions for den aspects.
# Aspects declare their settings here; hosts set them with proper types and defaults.
# Accessed by aspects via host.settings.<aspect-name>.<option>.
{ lib, inputs, ... }:
{
  den.schema.host =
    { config, ... }:
    let
      channels = {
        nixos-unstable = {
          nixosSystem = inputs.nixpkgs-unstable.lib.nixosSystem;
          darwinSystem = inputs.nix-darwin-unstable.lib.darwinSystem;
          home-manager-module.nixos = inputs.home-manager-unstable.nixosModules.home-manager;
          home-manager-module.darwin = inputs.home-manager-unstable.darwinModules.home-manager;
        };
        nixpkgs-master = {
          nixosSystem = inputs.nixpkgs-master.lib.nixosSystem;
          darwinSystem = inputs.nix-darwin-unstable.lib.darwinSystem;
          home-manager-module.nixos = inputs.home-manager-master.nixosModules.home-manager;
          home-manager-module.darwin = inputs.home-manager-master.darwinModules.home-manager;
        };
        nixos-stable = {
          nixosSystem = inputs.nixpkgs.lib.nixosSystem;
          darwinSystem = inputs.nix-darwin.lib.darwinSystem;
          home-manager-module.nixos = inputs.home-manager.nixosModules.home-manager;
          home-manager-module.darwin = inputs.home-manager.darwinModules.home-manager;
        };
        nixpkgs-stable-darwin = {
          nixosSystem = inputs.nixpkgs-stable-darwin.lib.nixosSystem;
          darwinSystem = inputs.nix-darwin.lib.darwinSystem;
          home-manager-module.nixos = inputs.home-manager-stable-darwin.nixosModules.home-manager;
          home-manager-module.darwin = inputs.home-manager-stable-darwin.darwinModules.home-manager;
        };
      };

      resolvedChannel = channels.${config.channel};
    in
    {
      options = {
        channel = lib.mkOption {
          type = lib.types.enum (builtins.attrNames channels);
          default = "nixos-unstable";
          description = "Nixpkgs channel — determines nixpkgs, home-manager, and nix-darwin versions";
        };

        # Computed IPs from networking interfaces (matching old host type)
        ipv4 = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          default =
            let
              interfaces = config.networking.interfaces or { };
              ifNames = builtins.attrNames interfaces;
              firstIf = if ifNames != [ ] then interfaces.${builtins.head ifNames} else { };
              stripCidr = addr: builtins.head (lib.splitString "/" addr);
            in
            map stripCidr (firstIf.ipv4 or [ ]);
          description = "Primary IPv4 addresses (derived from first networking interface, CIDR stripped)";
        };

        ipv6 = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          default =
            let
              interfaces = config.networking.interfaces or { };
              ifNames = builtins.attrNames interfaces;
              firstIf = if ifNames != [ ] then interfaces.${builtins.head ifNames} else { };
            in
            firstIf.ipv6 or [ ];
          description = "Primary IPv6 addresses (derived from first networking interface)";
        };

        # Primary user owning this host (for libvirt, etc.)
        system-owner = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Primary user name for this host";
        };

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

          bgp = {
            localAsn = lib.mkOption {
              type = lib.types.int;
              default = 65000;
              description = "Local BGP autonomous system number";
            };
          };

          cilium-bgp = {
            localAsn = lib.mkOption {
              type = lib.types.int;
              default = 65010;
              description = "Cilium BGP autonomous system number";
            };
          };

          thunderbolt-mesh-of = {
            interfaces = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Thunderbolt network interfaces for OpenFabric mesh";
            };
            loopback = {
              ipv4 = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Loopback IPv4 address with prefix (e.g., 172.16.255.1/32)";
              };
              ipv6 = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Loopback IPv6 address with prefix (optional)";
              };
            };
            nsap = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "IS-IS NSAP address (e.g., 49.0000.0000.0001.00)";
            };
          };

          k3s = {
            role = lib.mkOption {
              type = lib.types.enum [
                "server"
                "agent"
              ];
              default = "server";
              description = "K3s node role";
            };
            clusterInit = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether this node initializes the cluster";
            };
          };
        };
      };

      # Set instantiate and home-manager module from channel (overridable per-host)
      config = {
        instantiate = lib.mkDefault (
          if config.class == "darwin" then resolvedChannel.darwinSystem else resolvedChannel.nixosSystem
        );

        # Per-channel home-manager module — den's HM provider reads this
        home-manager.module = lib.mkDefault (
          if config.class == "darwin" then
            resolvedChannel.home-manager-module.darwin
          else
            resolvedChannel.home-manager-module.nixos
        );
      };
    };
}
