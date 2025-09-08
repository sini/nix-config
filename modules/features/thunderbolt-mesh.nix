# Thunderbolt mesh networking for 3-node cluster
# Automatically configures topology based on node number
{
  flake.modules.nixos.thunderbolt-mesh =
    {
      lib,
      config,
      ...
    }:
    let
      cfg = config.hardware.networking.thunderboltFabric;
      interfaces = [
        "enp199s0f5"
        "enp199s0f6"
      ];

      # Complete topology definition for the 3-node mesh
      # Node 1 <-> Node 2 (link 12)
      # Node 2 <-> Node 3 (link 23)
      # Node 3 <-> Node 1 (link 31)
      topologyMap = {
        "1" = {
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
        "2" = {
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
        "3" = {
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

      # Get node config or fallback to manual configuration
      nodeConfig = topologyMap.${toString cfg.nodeId} or null;

      # If using topology, override individual options with calculated values
      actualLoopback = if nodeConfig != null then nodeConfig.loopback else cfg.loopbackAddress;
      actualInterfaceIps = if nodeConfig != null then nodeConfig.interfaceIps else cfg.interfaceIps;
      actualLocalAsn = if nodeConfig != null then nodeConfig.localAsn else cfg.bgp.localAsn;
      actualPeers = if nodeConfig != null then nodeConfig.peers else cfg.bgp.peers;
    in
    {
      options.hardware.networking.thunderboltFabric = {
        # Simple node ID option - set this to 1, 2, or 3 for automatic configuration
        nodeId = lib.mkOption {
          type = lib.types.nullOr (lib.types.ints.between 1 3);
          default = null;
          description = ''
            Node ID in the 3-node mesh (1, 2, or 3).
            When set, automatically configures all networking based on predefined topology.
            Leave null to use manual configuration via other options.
          '';
        };

        # Manual configuration options (used when nodeId is null)
        loopbackAddress = {
          ipv4 = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "172.16.255.1/32";
            description = "IPv4 loopback address (unused when nodeId is set)";
          };
          ipv6 = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "fdb4:5edb:1b00::1/128";
            description = "IPv6 loopback address (unused when nodeId is set)";
          };
        };

        interfaceIps = {
          enp199s0f5 = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "169.254.12.1/31";
            description = "IP address for first thunderbolt interface (unused when nodeId is set)";
          };
          enp199s0f6 = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "169.254.13.1/31";
            description = "IP address for second thunderbolt interface (unused when nodeId is set)";
          };
        };

        bgp = {
          peers = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  asn = lib.mkOption { type = lib.types.int; };
                  lanip = lib.mkOption { type = lib.types.str; };
                  ip = lib.mkOption { type = lib.types.str; };
                  gateway = lib.mkOption { type = lib.types.str; };
                };
              }
            );
            default = [ ];
            description = "List of BGP peers (unused when nodeId is set)";
          };

          localAsn = lib.mkOption {
            type = lib.types.int;
            default = 65001;
            description = "Local AS number (unused when nodeId is set)";
          };

          ciliumAsn = lib.mkOption {
            type = lib.types.int;
            default = 65010;
            description = "ASN for the Cilium agent BGP instance";
          };

          podCidr = lib.mkOption {
            type = lib.types.str;
            default = "172.20.0.0/16";
            description = "The Kubernetes Pod CIDR block";
          };
        };
      };

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
            '') actualPeers}
            !
            !
            ! == Prefix Lists and Route Map to FIX Ingress Routes from Cilium ==
            ! This prefix-list permits both Pod CIDRs and Service CIDRs.
            ip prefix-list CILIUM-ROUTES seq 10 permit 172.16.0.0/12 ge 16 le 32
            ip prefix-list CILIUM-ROUTES seq 20 permit 192.168.0.0/16 ge 16 le 32
            ip prefix-list CILIUM-ROUTES seq 30 permit 10.0.0.0/8 le 32
            ip prefix-list DEFAULT-ONLY seq 10 permit 0.0.0.0/0
            !
            ! This is the CRITICAL FIX. This route-map matches the routes from Cilium
            ! and overwrites their next-hop with this node's own stable loopback IP.
            route-map CILIUM-INGRESS-FIX permit 10
              match ip address prefix-list CILIUM-ROUTES
              set ip next-hop ${lib.removeSuffix "/32" actualLoopback.ipv4}
            route-map FROM-UPLINK-IN permit 10
              match ip address prefix-list DEFAULT-ONLY
            !
            !
            ! Main BGP configuration
            !
            router bgp ${toString actualLocalAsn}
              bgp router-id ${lib.removeSuffix "/32" actualLoopback.ipv4}
              no bgp ebgp-requires-policy
              bgp bestpath as-path multipath-relax
              maximum-paths 8
              bgp allow-martian-nexthop
              !
              ! == Peer Definitions ==
              neighbor cilium peer-group
              neighbor cilium remote-as ${toString actualLocalAsn}
              neighbor cilium soft-reconfiguration inbound
              neighbor cilium update-source dummy0
              neighbor cilium ebgp-multihop 4
              bgp listen range ${actualLoopback.ipv4} peer-group cilium
              !
              neighbor 10.10.10.1 remote-as 65000
              neighbor 10.10.10.1 route-map FROM-UPLINK-IN in
              ${lib.concatMapStringsSep "\n" (peer: ''
                neighbor ${peer.ip} remote-as ${toString peer.asn}
                neighbor ${peer.ip} update-source dummy0
                neighbor ${peer.ip} soft-reconfiguration inbound
                neighbor ${peer.ip} ebgp-multihop 4
                neighbor ${peer.ip} allowas-in 1
              '') actualPeers}
              !
              ! Address Family configuration for IPv4
              address-family ipv4 unicast
                network ${actualLoopback.ipv4}
                neighbor 10.10.10.1 activate
                neighbor cilium activate
                neighbor cilium next-hop-self
              ${lib.concatMapStringsSep "\n" (peer: ''
                neighbor ${peer.ip} activate
                neighbor ${peer.ip} next-hop-self
              '') actualPeers}

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
                  actualLoopback.ipv4
                  actualLoopback.ipv6
                ];
              };
              "21-thunderbolt-1" = {
                matchConfig.Name = "enp199s0f5";
                address = [ actualInterfaceIps.enp199s0f5 ];
                linkConfig = {
                  ActivationPolicy = "up";
                  MTUBytes = "9000"; # Recommended for performance
                };
                networkConfig.LinkLocalAddressing = "no";
              };
              "21-thunderbolt-2" = {
                matchConfig.Name = "enp199s0f6";
                address = [ actualInterfaceIps.enp199s0f6 ];
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
