{ config, ... }:
{
  flake.hosts.axon-01 = {
    ipv4 = [ "10.10.10.2" ];
    ipv6 = [ "fd64:0:1::2/64" ];
    environment = "prod";
    roles = [
      "server"
      "kubernetes"
      "kubernetes-master"
      "bgp-spoke"
      "vault"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-longhorn
      cpu-amd
      gpu-amd
      thunderbolt-mesh
    ];
    tags = {
      "kubernetes-internal-ip" = "172.16.255.1";
      "bgp-asn" = "65001";
      "thunderbolt-loopback-ipv4" = "172.16.255.1/32";
      "thunderbolt-loopback-ipv6" = "fdb4:5edb:1b00::1/128";
      "thunderbolt-interface-1" = "169.254.12.0/31";
      "thunderbolt-interface-2" = "169.254.31.1/31";
    };
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINE2Tsb0nKZ1oFYaCENTO58S3/rz3PMISS6llUVkQi7+";
    facts = ./facter.json;
    nixosConfiguration =
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
  };
}
