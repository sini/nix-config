{ config, ... }:
{
  networks.home = {
    name = "home";
    cidrv4 = "10.10.0.0/16";
  };

  nodes = {
    surge.interfaces.eth0.network = "home";
    pulse.interfaces.eth0.network = "home";
    burst.interfaces.eth0.network = "home";

    # internet = mkInternet {
    #   connections = mkConnection "router" "wan1";
    # };
    #
    # router = mkRouter "linksys" {
    #   info = "Linksys0218";
    #   interfaceGroups = [
    #     ["eth1" "eth2"]
    #     ["wan1"]
    #   ];
    #   connections.eth1 = mkConnection "aurora" "enp0s31f6";
    #   connections.eth2 = mkConnection "equinox" "eno1";
    #
    #   interfaces.eth1.network = "home";
    #   interfaces.eth2.network = "home";
    # };
  };
}
