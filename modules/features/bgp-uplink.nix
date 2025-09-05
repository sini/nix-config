#
{
  flake.modules.nixos.bgp-uplink = {
    # boot = {
    #   kernel.sysctl = {
    #     "net.ipv4.ip_forward" = 1;
    #     "net.ipv4.conf.all.proxy_arp" = true;
    #     "net.ipv6.conf.all.forwarding" = 1;
    #   };
    # };

    services.frr = {
      bgpd.enable = true;
      config = ''
        ip forwarding
        !
        router bgp 65000
          bgp router-id 10.10.10.1
          no bgp ebgp-requires-policy
          bgp bestpath as-path multipath-relax
          !maximum-paths 8
          !
          ! Define the three axon nodes as iBGP neighbors.
          ! They are in the same AS (65001).
          neighbor 10.10.10.2 remote-as 65001
          neighbor 10.10.10.3 remote-as 65002
          neighbor 10.10.10.4 remote-as 65003
          !
          address-family ipv4 unicast
            ! Activate all neighbors
            neighbor 10.10.10.2 activate
            neighbor 10.10.10.3 activate
            neighbor 10.10.10.4 activate
          exit-address-family
      '';
    };
  };
}
