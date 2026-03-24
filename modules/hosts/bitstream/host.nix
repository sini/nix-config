{
  hosts.bitstream = {
    networking.interfaces = {
      eno1 = {
        ipv4 = [ "10.9.1.1" ];
        ipv6 = [ "2001:5a8:608c:4a00::1/64" ];
      };
      enp2s0 = {
        ipv4 = [ "10.9.1.2" ];
        ipv6 = [ "2001:5a8:608c:4a00::2/64" ];
      };
    };
    environment = "dev";
    extra-features = [
      # Composite features (formerly roles)
      "server"
      "nix-builder"

      # Hardware and system features
      "zfs-disk-single"
      "network-boot"
      "cpu-amd"
      "gpu-amd"
    ];
    feature-settings.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_0023065001TG";

    facts = ./facter.json;
    systemConfiguration =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-server-lto;

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
        system.stateVersion = "25.11";
      };
  };
}
