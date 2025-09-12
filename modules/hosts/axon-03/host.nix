{ config, ... }:
{
  flake.hosts.axon-03 = {
    ipv4 = "10.10.10.4";
    environment = "prod";
    roles = [
      "server"
      "kubernetes"
      "bgp-spoke"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-longhorn
      cpu-amd
      gpu-amd
      thunderbolt-mesh
    ];
    tags = {
      "kubernetes-internal-ip" = "172.16.255.3";
      "bgp-asn" = "65003";
      "thunderbolt-loopback-ipv4" = "172.16.255.3/32";
      "thunderbolt-loopback-ipv6" = "fdb4:5edb:1b00::3/128";
      "thunderbolt-interface-1" = "169.254.31.0/31";
      "thunderbolt-interface-2" = "169.254.23.1/31";
    };
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOAXXsNWa09hW/wuDBcpMkln9LsZCM0A2vQYiUh+pEsC";
    facts = ./facter.json;
  };

  flake.modules.nixos.host_axon-03 =
    {
      pkgs,
      ...
    }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;

      hardware = {
        networking = {
          interfaces = [ "enp2s0" ];
          unmanagedInterfaces = [ "enp2s0" ];
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
