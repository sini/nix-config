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
      thunderbolt-mesh
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

      #k3s.ipv4 = "172.16.255.1";

      hardware = {
        networking = {
          interfaces = [ "enp2s0" ];
          unmanagedInterfaces = [ "enp2s0" ];
          thunderboltFabric = {
            loopbackAddress = {
              ipv4 = "172.16.255.1/32"; # TODO: extend range
              ipv6 = "fdb4:5edb:1b00::1/128";
            };
            interfaceIps = {
              # This interface connects to node2.enp199s0f6
              enp199s0f5 = "169.254.12.0/31";
              # This interface connects to node3.enp199s0f5
              enp199s0f6 = "169.254.31.1/31";
            };
            bgp = {
              localAsn = 65001;
              peers = [
                # Peer with Node 2 over the 1-2 Link
                {
                  asn = 65002;
                  ip = "172.16.255.2";
                  gateway = "169.254.12.1";
                }
                # Peer with Node 3 over the 3-1 Link
                {
                  asn = 65003;
                  ip = "172.16.255.3";
                  gateway = "169.254.31.0";
                }
              ];
            };
          };
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

      system.stateVersion = "25.05";
    };

}
