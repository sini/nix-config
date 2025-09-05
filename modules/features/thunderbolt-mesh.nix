# Inspired by: https://github.com/Stinjul/nixfiles/blob/main/modules/nixos/thunderbolt-network.nix
#
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
    in
    {
      options.hardware.networking.thunderboltFabric = {
        loopbackAddress = {
          ipv4 = lib.mkOption {
            type = lib.types.str;
            example = "172.16.255.1/32";
          };
          ipv6 = lib.mkOption {
            type = lib.types.str;
            example = "fdb4:5edb:1b00::1/128";
          };
        };

        interfaceIps = {
          enp199s0f5 = lib.mkOption {
            type = lib.types.str;
            example = "169.254.12.1/31";
          };
          enp199s0f6 = lib.mkOption {
            type = lib.types.str;
            example = "169.254.13.1/31";
          };
        };

        bgp = {

          # Define the cluster nodes to peer with.
          peers = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  asn = lib.mkOption { type = lib.types.int; };
                  ip = lib.mkOption { type = lib.types.str; };
                  gateway = lib.mkOption { type = lib.types.str; };
                };
              }
            );
            default = [ ];
            example = ''
              [
                { ip = "172.16.255.2"; }
                { ip = "172.16.255.3"; }
              ]
            '';
            description = "List of BGP peers (other nodes in the cluster).";
          };

          # This is the ASN for THIS node's FRR instance.
          localAsn = lib.mkOption {
            type = lib.types.int;
            default = 65001;
            description = "Autonomous System Number for the internal FRR network.";
          };

          # Define the ASN for the Cilium agent.
          ciliumAsn = lib.mkOption {
            type = lib.types.int;
            default = 65010;
            description = "ASN for the Cilium agent BGP instance.";
          };

          # Define the Pod CIDR to accept from Cilium.
          podCidr = lib.mkOption {
            type = lib.types.str;
            default = "172.20.0.0/16";
            description = "The Kubernetes Pod CIDR block.";
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
            ! Static routes to bootstrap iBGP peering over loopbacks.
            ${lib.concatMapStringsSep "\n" (peer: ''
              ip route ${peer.ip}/32 ${peer.gateway}
            '') cfg.bgp.peers}
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
              set ip next-hop ${lib.removeSuffix "/32" cfg.loopbackAddress.ipv4}
            route-map FROM-UPLINK-IN permit 10
              match ip address prefix-list DEFAULT-ONLY
            !
            !
            ! Main BGP configuration
            !
            router bgp ${toString cfg.bgp.localAsn}
              bgp router-id ${lib.removeSuffix "/32" cfg.loopbackAddress.ipv4}
              no bgp ebgp-requires-policy
              bgp bestpath as-path multipath-relax
              bgp allow-martian-nexthop
              !
              ! == Peer Definitions ==
              neighbor cilium peer-group
              neighbor cilium remote-as ${toString cfg.bgp.localAsn}
              neighbor cilium soft-reconfiguration inbound
              neighbor cilium update-source dummy0
              neighbor cilium ebgp-multihop 4
              bgp listen range ${cfg.loopbackAddress.ipv4} peer-group cilium
              !
              neighbor 10.10.10.1 remote-as 65000
              neighbor 10.10.10.1 route-map FROM-UPLINK-IN in
              ${lib.concatMapStringsSep "\n" (peer: ''
                neighbor ${peer.ip} remote-as ${toString peer.asn}
                neighbor ${peer.ip} update-source dummy0
                neighbor ${peer.ip} soft-reconfiguration inbound
                neighbor ${peer.ip} ebgp-multihop 4
                neighbor ${peer.ip} allowas-in 1
              '') cfg.bgp.peers}
              !
              ! Address Family configuration for IPv4
              address-family ipv4 unicast
                network ${cfg.loopbackAddress.ipv4}
                neighbor 10.10.10.1 activate
                neighbor cilium activate
                neighbor cilium next-hop-self
              ${lib.concatMapStringsSep "\n" (peer: ''
                neighbor ${peer.ip} activate
                neighbor ${peer.ip} next-hop-self
              '') cfg.bgp.peers}

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
                  cfg.loopbackAddress.ipv4
                  cfg.loopbackAddress.ipv6
                ];
              };
              "21-thunderbolt-1" = {
                matchConfig.Name = "enp199s0f5";
                address = [ cfg.interfaceIps.enp199s0f5 ];
                linkConfig = {
                  ActivationPolicy = "up";
                  MTUBytes = "9000"; # Recommended for performance
                };
                networkConfig.LinkLocalAddressing = "no";
              };
              "21-thunderbolt-2" = {
                matchConfig.Name = "enp199s0f6";
                address = [ cfg.interfaceIps.enp199s0f6 ];
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
