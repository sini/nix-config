{ config, ... }:
{
  flake.hosts.axon-03 = {
    ipv4 = "10.10.10.4";
    roles = [
      "server"
      "kubernetes"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-longhorn
      cpu-amd
      gpu-amd
      thunderbolt-mesh
    ];
    tags = {
      "kubernetes-cluster" = "dev";
    };
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOAXXsNWa09hW/wuDBcpMkln9LsZCM0A2vQYiUh+pEsC root@axon-03";
    facts = ./facter.json;
  };

  flake.modules.nixos.host_axon-03 =
    {
      pkgs,
      ...
    }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;

      k3s.ipv4 = "172.16.255.3";

      hardware = {
        networking = {
          interfaces = [ "enp2s0" ];
          unmanagedInterfaces = [ "enp2s0" ];
          thunderboltFabric = {
            loopbackAddress = {
              ipv4 = "172.16.255.3/32"; # TODO: move and extend range
              ipv6 = "fdb4:5edb:1b00::3/128";
            };
            interfaceIps = {
              # This interface connects to node1.enp199s0f6
              enp199s0f5 = "169.254.31.0/31";
              # This interface connects to node2.enp199s0f5
              enp199s0f6 = "169.254.23.1/31";
            };
            bgp = {
              localAsn = 65003;
              peers = [
                # Peer with Node 1 over the 3-1 Link
                {
                  asn = 65001;
                  localip = "10.10.10.2";
                  ip = "172.16.255.1";
                  gateway = "169.254.31.1";
                }
                # Peer with Node 2 over the 2-3 Link
                {
                  asn = 65002;
                  localip = "10.10.10.3";
                  ip = "172.16.255.2";
                  gateway = "169.254.23.0";
                }
              ];
            };
          };
        };
        disk.longhorn = {
          os_drive = {
            device_id = "nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300CCCC";
            swap_size = 8192;
          };
          longhorn_drive = {
            device_id = "nvme-Force_MP600_1925823000012856500E";
          };
        };
      };

      system.stateVersion = "25.05";
    };
}
