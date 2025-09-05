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
        ! FRR configuration for the 'uplink' machine
        !
        frr version 8.x
        frr defaults traditional
        hostname uplink
        log stdout
        router bgp 65000
          ! Use the loopback IP of this machine as a stable router ID
          bgp router-id 10.10.10.1
          no bgp ebgp-requires-policy
          bgp bestpath as-path multipath-relax
          !
          ! Define the three axon nodes as iBGP neighbors.
          ! They are in the same AS (65001).
          neighbor 10.10.10.2 remote-as 65001
          neighbor 10.10.10.3 remote-as 65002
          neighbor 10.10.10.4 remote-as 65003
          !
          ! This is the critical command to enable ECMP across the 3 links.
          ! A value of 8 is a safe, common default.
          maximum-paths 8
      '';
    };
  };
}
