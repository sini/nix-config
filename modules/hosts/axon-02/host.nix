{ ... }:
{
  flake.hosts.axon-02 = {
    ipv4 = [ "10.10.10.3" ];
    ipv6 = [ "fd64:0:1::3/64" ];
    environment = "prod";
    roles = [
      "server"
      # "kubernetes"
      # "bgp-spoke"
      # "vault"
    ];
    features = [
      "disk-single"
      "disk-longhorn"
      "cpu-amd"
      "gpu-amd"
      # "thunderbolt-mesh"
    ];
    tags = {
      "kubernetes-internal-ip" = "172.16.255.2";
      "bgp-asn" = "65002";
      "thunderbolt-loopback-ipv4" = "172.16.255.2/32";
      "thunderbolt-loopback-ipv6" = "fdb4:5edb:1b00::2/128";
      "thunderbolt-interface-1" = "169.254.23.0/31";
      "thunderbolt-interface-2" = "169.254.12.1/31";
    };
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        boot.kernelPackages = pkgs.linuxPackages_cachyos-server.cachyOverride { mArch = "ZEN4"; };

        hardware = {
          networking = {
            interfaces = [ "enp2s0" ];
            unmanagedInterfaces = [ "enp2s0" ];
          };
          disk.single = {
            device_id = "nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
            swap_size = 8192;
          };
          disk.longhorn = {

            longhorn_drive = {
              device_id = "nvme-Force_MP600_192482300001285610CF";
            };
          };
        };

        system.stateVersion = "25.05";
      };
  };
}
