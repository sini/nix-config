{ config, ... }:
{
  flake.hosts.axon-02 = {
    ipv4 = "10.10.10.3";
    roles = [
      "server"
      #"kubernetes"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-longhorn
      cpu-amd
      gpu-amd
    ];
    tags = {
      "kubernetes-cluster" = "dev";
    };
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDanYqvi+/2Pp57Vw19DHVfQ0VSMXHBdnHLntW+Lr/8h root@axon-02";
    facts = ./facter.json;
  };

  flake.modules.nixos.host_axon-02 =
    {
      pkgs,
      ...
    }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;

      hardware = {
        networking.interfaces = [ "enp2s0" ];
        disk.longhorn = {
          os_drive = {
            device_id = "nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
            swap_size = 8192;
          };
          longhorn_drive = {
            device_id = "nvme-Force_MP600_192482300001285610CF";
          };
        };
      };

      # boot.kernelModules = [
      #   "thunderbolt"
      #   "thunderbolt-net"
      # ];

      # # To axon-01
      # systemd.network.links."50-tbt-02" = {
      #   matchConfig = {
      #     Path = "pci-0000:c7:00.5";
      #     Driver = "thunderbolt-net";
      #   };
      #   linkConfig = {
      #     MACAddressPolicy = "none";
      #     Name = "tbt-02";
      #   };
      # };
      # systemd.network.networks.tbt-02 = {
      #   matchConfig = {
      #     Path = "pci-0000:c7:00.5";
      #     Driver = "thunderbolt-net";
      #   };
      #   addresses = [
      #     {
      #       addressConfig = {
      #         Address = "10.7.0.103/32";
      #         Peer = "10.7.0.101/32";
      #       };
      #     }
      #   ];
      # };

      system.stateVersion = "25.05";
    };
}
