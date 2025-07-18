_: {
  # Disable the default networking configuration
  hardware.networking.enable = false;

  networking = {
    dhcpcd.enable = false;
    useDHCP = true;
    useNetworkd = true;
    networkmanager.enable = false;
  };
  systemd.network = {
    enable = true;
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
}
