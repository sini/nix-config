{ ... }:
{
  flake.hosts.bitstream = {
    ipv4 = [
      "10.9.1.1"
      "10.9.1.2"
    ];
    ipv6 = [
      "2001:5a8:608c:4a00::1/64"
      "2001:5a8:608c:4a00::2/64"
    ];
    environment = "dev";
    roles = [
      "server"
      "kubernetes"
      "kubernetes-master"
      #      "workstation"
      #      "gaming"
      #      "dev"
      #      "dev-gui"
      #      "media"
      # "vault"
    ];
    features = [
      "disk-single"
      "cpu-amd"
      "gpu-amd"
      "podman"
    ];
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        boot.kernelPackages = pkgs.linuxPackages_cachyos-server.cachyOverride { mArch = "GENERIC_V4"; };

        hardware = {
          disk.single = {
            device_id = "nvme-NVMe_CA6-8D1024_0023065001TG";
            swap_size = 8192;
          };
          networking = {
            interfaces = [
              "eno1"
              "enp2s0"
            ];
            # unmanagedInterfaces = [
            #   "eno1"
            #   "enp2s0"
            #   "bond0"
            # ];
          };
        };

        # systemd.network = {
        #   netdevs = {
        #     "10-bond0" = {
        #       netdevConfig = {
        #         Kind = "bond";
        #         Name = "bond0";
        #       };
        #       bondConfig = {
        #         # Mode = "balance-alb";
        #         Mode = "balance-xor";
        #         TransmitHashPolicy = "layer3+4";
        #       };
        #     };
        #   };

        #   # Configure Bonds to utilize both 2.5Gbps ports
        #   networks = {
        #     "30-eno1" = {
        #       enable = true;
        #       matchConfig.PermanentMACAddress = "84:47:09:40:d5:f5";
        #       networkConfig.Bond = "bond0";
        #     };

        #     "30-enp2s0" = {
        #       enable = true;
        #       matchConfig.PermanentMACAddress = "84:47:09:40:d5:f4";
        #       networkConfig.Bond = "bond0";
        #     };

        #     "40-bond0" = {
        #       enable = true;
        #       matchConfig.Name = "bond0";
        #       networkConfig = {
        #         DHCP = true;
        #         LinkLocalAddressing = "no";
        #       };
        #       linkConfig = {
        #         RequiredForOnline = "routable";
        #         MACAddress = "84:47:09:40:d5:f4";
        #       };
        #     };
        #   };
        # };
        networking.firewall.allowedTCPPorts = [
          12365
          53
        ];

        system.stateVersion = "25.05";
      };
  };
}
