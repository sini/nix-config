{ config, ... }:
{
  flake.hosts.axon-01 = {
    ipv4 = "10.10.10.2";
    roles = [
      "server"
      #"kubernetes"
      #"kubernetes-master"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-longhorn
      cpu-amd
      gpu-amd
    ];
    tags = {
      "kubernetes-cluster" = "dev";
      "kubernetes-master" = "true";
    };
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINE2Tsb0nKZ1oFYaCENTO58S3/rz3PMISS6llUVkQi7+ root@axon-01";
    facts = ./facter.json;
  };

  flake.modules.nixos.host_axon-01 =
    {
      pkgs,
      ...
    }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;

      hardware = {
        networking = {
          interfaces = [ "enp2s0" ];
          unmanagedInterfaces = [
            "enp2s0"
            "tb01"
            "tb02"
          ];
        };
        disk.longhorn = {
          os_drive = {
            device_id = "nvme-NVMe_CA6-8D1024_00230650035M";
            swap_size = 8192;
          };
          longhorn_drive = {
            device_id = "nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
          };
        };
      };

      boot = {
        kernel.sysctl = {
          "net.ipv4.ip_forward" = 1;
          "net.ipv6.conf.all.forwarding" = 1;
          # These need to be increased for k8s
          # Although the default settings might not cause issues initially, you'll get strange behavior after a while
          "fs.inotify.max_user_instances" = 1048576;
          "fs.inotify.max_user_watches" = 1048576;
        };
        kernelModules = [
          "thunderbolt"
          "thunderbolt-net"
        ];
      };

      # To axon-02
      systemd.network = {
        config.networkConfig = {
          IPv4Forwarding = true;
          IPv6Forwarding = true;
        };
        links = {
          "50-tb01" = {
            matchConfig = {
              Path = "pci-0000:c7:00.5";
              Driver = "thunderbolt-net";
            };
            linkConfig = {
              MACAddressPolicy = "none";
              Name = "tb01";
            };
          };
          "50-tb02" = {
            matchConfig = {
              Path = "pci-0000:c7:00.6";
              Driver = "thunderbolt-net";
            };
            linkConfig = {
              MACAddressPolicy = "none";
              Name = "tb02";
            };
          };
        };
        networks = {
          "21-thunderbolt" = {
            matchConfig.Driver = "thunderbolt-net";
            linkConfig = {
              ActivationPolicy = "up";
              MTUBytes = "1500";
            };
            networkConfig = {
              LinkLocalAddressing = "no";
            };
          };
        };
        # networks = {
        #   "tbt-02" = {
        #     matchConfig = {
        #       Path = "pci-0000:c7:00.5";
        #       Driver = "thunderbolt-net";
        #     };
        #     addresses = [
        #       {
        #         addressConfig = {
        #           Address = "10.7.0.101/32";
        #           Peer = "10.7.0.103/32";
        #         };
        #       }
        #     ];
        #   };
        # };
      };

      system.stateVersion = "25.05";
    };

}
