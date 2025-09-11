# Thunderbolt mesh networking for 3-node cluster
# Auto-detects node ID from hostname and configures topology
{
  flake.modules.nixos.thunderbolt-mesh =
    {
      lib,
      config,
      environment,
      ...
    }:
    let
      interfaces = [
        "enp199s0f5"
        "enp199s0f6"
      ];

      # Complete topology definition for the 3-node mesh
      # Node 1 <-> Node 2 (link 12)
      # Node 2 <-> Node 3 (link 23)
      # Node 3 <-> Node 1 (link 31)
      topologyMap = {
        "axon-01" = {
          loopback = {
            ipv4 = "172.16.255.1/32";
            ipv6 = "fdb4:5edb:1b00::1/128";
          };
          localAsn = 65001;
          interfaceIps = {
            enp199s0f5 = "169.254.12.0/31"; # connects to node 2
            enp199s0f6 = "169.254.31.1/31"; # connects to node 3
          };
          peers = [
            {
              asn = 65002;
              lanip = "10.10.10.3";
              ip = "172.16.255.2";
              gateway = "169.254.12.1";
            }
            {
              asn = 65003;
              lanip = "10.10.10.4";
              ip = "172.16.255.3";
              gateway = "169.254.31.0";
            }
          ];
        };
        "axon-02" = {
          loopback = {
            ipv4 = "172.16.255.2/32";
            ipv6 = "fdb4:5edb:1b00::2/128";
          };
          localAsn = 65002;
          interfaceIps = {
            enp199s0f5 = "169.254.23.0/31"; # connects to node 3
            enp199s0f6 = "169.254.12.1/31"; # connects to node 1
          };
          peers = [
            {
              asn = 65003;
              lanip = "10.10.10.4";
              ip = "172.16.255.3";
              gateway = "169.254.23.1";
            }
            {
              asn = 65001;
              lanip = "10.10.10.2";
              ip = "172.16.255.1";
              gateway = "169.254.12.0";
            }
          ];
        };
        "axon-03" = {
          loopback = {
            ipv4 = "172.16.255.3/32";
            ipv6 = "fdb4:5edb:1b00::3/128";
          };
          localAsn = 65003;
          interfaceIps = {
            enp199s0f5 = "169.254.31.0/31"; # connects to node 1
            enp199s0f6 = "169.254.23.1/31"; # connects to node 2
          };
          peers = [
            {
              asn = 65001;
              lanip = "10.10.10.2";
              ip = "172.16.255.1";
              gateway = "169.254.31.1";
            }
            {
              asn = 65002;
              lanip = "10.10.10.3";
              ip = "172.16.255.2";
              gateway = "169.254.23.0";
            }
          ];
        };
      };

      uplinkIp = "10.10.10.1";

      # Get the configuration for this node
      nodeConfig = topologyMap.${toString config.networking.hostName};
    in
    {
      # No options needed - configuration is auto-detected from hostname

      config = {
        hardware.networking.unmanagedInterfaces = interfaces;

        boot = {
          kernelParams = [
            "pcie=pcie_bus_perf"
          ];
          kernelModules = [
            "dummy"
            "thunderbolt"
            "thunderbolt-net"
          ];
        };

        services.frr = {
          bgpd.enable = true;
          config = ''
            ip forwarding
            !
            ! Static routes to bootstrap BGP peering over loopbacks.
            ${lib.concatMapStringsSep "\n" (peer: ''
              ip route ${peer.ip}/32 ${peer.gateway}
              ip route ${peer.lanip}/32 ${peer.gateway}
            '') nodeConfig.peers}
            !
            !
            ! == Prefix Lists and Route Map to FIX Ingress Routes from Cilium ==
            ! This prefix-list permits both Pod CIDRs and Service CIDRs.
            ip prefix-list CILIUM-ROUTES seq 10 permit ${environment.kubernetes.clusterCidr} ge 16 le 32
            ip prefix-list CILIUM-ROUTES seq 20 permit ${environment.kubernetes.serviceCidr} ge 16 le 32
            ip prefix-list CILIUM-ROUTES seq 30 permit 10.0.0.0/8 le 32
            ip prefix-list DEFAULT-ONLY seq 10 permit 0.0.0.0/0
            !
            ! This is the CRITICAL FIX. This route-map matches the routes from Cilium
            ! and overwrites their next-hop with this node's own stable loopback IP.
            route-map CILIUM-INGRESS-FIX permit 10
              match ip address prefix-list CILIUM-ROUTES
              set ip next-hop ${lib.removeSuffix "/32" nodeConfig.loopback.ipv4}
            route-map FROM-UPLINK-IN permit 10
              match ip address prefix-list DEFAULT-ONLY
            !
            !
            ! Main BGP configuration
            !
            router bgp ${toString nodeConfig.localAsn}
              bgp router-id ${lib.removeSuffix "/32" nodeConfig.loopback.ipv4}
              no bgp ebgp-requires-policy
              bgp bestpath as-path multipath-relax
              maximum-paths 8
              bgp allow-martian-nexthop
              !
              ! == Peer Definitions ==
              neighbor cilium peer-group
              neighbor cilium remote-as ${toString nodeConfig.localAsn}
              neighbor cilium soft-reconfiguration inbound
              neighbor cilium update-source dummy0
              neighbor cilium ebgp-multihop 4
              bgp listen range ${nodeConfig.loopback.ipv4} peer-group cilium
              !
              neighbor ${uplinkIp} remote-as 65000
              neighbor ${uplinkIp} route-map FROM-UPLINK-IN in
              ${lib.concatMapStringsSep "\n" (peer: ''
                neighbor ${peer.ip} remote-as ${toString peer.asn}
                neighbor ${peer.ip} update-source dummy0
                neighbor ${peer.ip} soft-reconfiguration inbound
                neighbor ${peer.ip} ebgp-multihop 4
                neighbor ${peer.ip} allowas-in 1
              '') nodeConfig.peers}
              !
              ! Address Family configuration for IPv4
              address-family ipv4 unicast
                network ${nodeConfig.loopback.ipv4}
                neighbor ${uplinkIp} activate
                neighbor cilium activate
                neighbor cilium next-hop-self
              ${lib.concatMapStringsSep "\n" (peer: ''
                neighbor ${peer.ip} activate
                neighbor ${peer.ip} next-hop-self
              '') nodeConfig.peers}

              exit-address-family
            !
          '';

        };

        systemd = {
          services = {
            frr = {
              requires = lib.lists.forEach interfaces (i: "sys-subsystem-net-devices-${i}.device");
              after = lib.lists.forEach interfaces (i: "sys-subsystem-net-devices-${i}.device");
            };
          };
          network = {
            config.networkConfig = {
              IPv4Forwarding = true;
              IPv6Forwarding = true;
            };

            netdevs = {
              dummy0 = {
                netdevConfig = {
                  Kind = "dummy";
                  Name = "dummy0";
                };
              };
            };

            links = {
              "20-thunderbolt-port-1" = {
                matchConfig = {
                  Path = "pci-0000:c7:00.5";
                  Driver = "thunderbolt-net";
                };
                linkConfig = {
                  Name = "enp199s0f5";
                  Alias = "tb1";
                  AlternativeName = "tb1";
                };
              };
              "20-thunderbolt-port-2" = {
                matchConfig = {
                  Path = "pci-0000:c7:00.6";
                  Driver = "thunderbolt-net";
                };
                linkConfig = {
                  Name = "enp199s0f6";
                  Alias = "tb2";
                  AlternativeName = "tb2";
                };
              };
            };

            networks = {
              "00-dummy" = {
                matchConfig.Name = "dummy0";
                address = [
                  nodeConfig.loopback.ipv4
                  nodeConfig.loopback.ipv6
                ];
              };
              "21-thunderbolt-1" = {
                matchConfig.Name = "enp199s0f5";
                address = [ nodeConfig.interfaceIps.enp199s0f5 ];
                linkConfig = {
                  ActivationPolicy = "up";
                  MTUBytes = "9000"; # Recommended for performance
                };
                networkConfig.LinkLocalAddressing = "no";
              };
              "21-thunderbolt-2" = {
                matchConfig.Name = "enp199s0f6";
                address = [ nodeConfig.interfaceIps.enp199s0f6 ];
                linkConfig = {
                  ActivationPolicy = "up";
                  MTUBytes = "9000"; # Recommended for performance
                };
                networkConfig.LinkLocalAddressing = "no";
              };
            };
          };
        };
      };
    };
}
