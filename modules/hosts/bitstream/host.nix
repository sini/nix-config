{ config, ... }:
{
  flake.hosts.bitstream = {
    ipv4 = "10.10.10.5";
    roles = [
      "server"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-single
      cpu-amd
      gpu-amd
      podman
    ];
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIKFdt1A2dHlqDpSTvw85Iu6JHlVM/ERYAeMT95vLaVc";
    facts = ./facter.json;
  };

  flake.modules.nixos.host_bitstream =
    {
      pkgs,
      ...
    }:
    {

      boot.kernelPackages = pkgs.linuxPackages_latest;

      hardware = {
        disk.single = {
          device_id = "nvme-NVMe_CA6-8D1024_0023065001TG";
          swap_size = 8192;
        };
        networking = {
          interfaces = [ ];
          unmanagedInterfaces = [
            "eno1"
            "enp2s0"
            "bond0"
          ];
        };
      };

      systemd.network = {
        netdevs = {
          "10-bond0" = {
            netdevConfig = {
              Kind = "bond";
              Name = "bond0";
            };
            bondConfig = {
              # Mode = "balance-alb";
              Mode = "balance-xor";
              TransmitHashPolicy = "layer3+4";
            };
          };
        };

        # Configure Bonds to utilize both 2.5Gbps ports
        networks = {
          "30-eno1" = {
            enable = true;
            matchConfig.PermanentMACAddress = "84:47:09:40:d5:f5";
            networkConfig.Bond = "bond0";
          };

          "30-enp2s0" = {
            enable = true;
            matchConfig.PermanentMACAddress = "84:47:09:40:d5:f4";
            networkConfig.Bond = "bond0";
          };

          "40-bond0" = {
            enable = true;
            matchConfig.Name = "bond0";
            networkConfig = {
              DHCP = true;
              LinkLocalAddressing = "no";
            };
            linkConfig = {
              RequiredForOnline = "routable";
              MACAddress = "84:47:09:40:d5:f4";
            };
          };
        };
      };

      system.stateVersion = "25.05";
    };
}
