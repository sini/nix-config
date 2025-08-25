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
          # This is the ASN for THIS node's FRR instance.
          localAsn = lib.mkOption {
            type = lib.types.int;
            default = 65001;
            description = "Autonomous System Number for the internal FRR network.";
          };

          # Define the cluster nodes to peer with.
          peers = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  ip = lib.mkOption { type = lib.types.str; };
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

          # Define the ASN for the Cilium agent.
          ciliumAsn = lib.mkOption {
            type = lib.types.int;
            default = 65002;
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
          # kernel.sysctl = {
          #   "net.ipv4.ip_forward" = 1;
          #   "net.ipv4.conf.all.proxy_arp" = true;
          #   "net.ipv6.conf.all.forwarding" = 1;
          # };
          kernelModules = [
            "thunderbolt"
            "thunderbolt-net"
          ];
        };

        services.frr = {
          bgpd.enable = true;
          config = ''
            ip forwarding
            ! BGP route filtering for Cilium Pod CIDRs
            ip prefix-list CILIUM_POD_CIDRS permit ${cfg.bgp.podCidr} le 32
            !
            route-map FROM_CILIUM permit 10
            match ip address prefix-list CILIUM_POD_CIDRS
            set ip next-hop ${lib.removeSuffix "/32" cfg.loopbackAddress.ipv4}
            ! BGP Router (Now handles EVERYTHING)
            router bgp ${toString cfg.bgp.localAsn}
              bgp router-id ${lib.removeSuffix "/32" cfg.loopbackAddress.ipv4}
              ! Peer with the local Cilium agent
              neighbor 127.0.0.1 remote-as ${toString cfg.bgp.ciliumAsn}
              neighbor 127.0.0.1 ebgp-multihop 2
              !
              ! Peer with the other cluster nodes
              ${lib.concatMapStringsSep "\n" (peer: ''
                neighbor ${peer.ip} remote-as ${toString cfg.bgp.localAsn}
                neighbor ${peer.ip} update-source lo
              '') cfg.bgp.peers}
              !
              ! Address Family Configuration
              address-family ipv4 unicast
                !
                ! Advertise this host's own loopback IP to other nodes
                network ${cfg.loopbackAddress.ipv4}
                !
                ! Activate the Cilium neighbor and apply the filter
                neighbor 127.0.0.1 activate
                neighbor 127.0.0.1 route-map FROM_CILIUM in
                !
                ! Activate the cluster node neighbors
                ${lib.concatMapStringsSep "\n" (peer: ''
                  neighbor ${peer.ip} activate
                  neighbor ${peer.ip} next-hop-self
                '') cfg.bgp.peers}
                maximum-paths 8
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
              "00-loopback" = {
                matchConfig.Name = "lo";
                address = [ cfg.loopbackAddress.ipv4 ];
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
