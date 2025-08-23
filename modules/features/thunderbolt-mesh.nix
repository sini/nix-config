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
        nsap = lib.mkOption {
          type = lib.types.str;
          example = "49.0000.0000.0001.00";
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
                  asn = lib.mkOption { type = lib.types.int; };
                };
              }
            );
            default = [ ];
            example = ''
              [
                { ip = "172.16.255.2"; asn = 65001; }
                { ip = "172.16.255.3"; asn = 65001; }
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
          fabricd.enable = true;
          config = ''
            ip forwarding
            ipv6 forwarding
            !
            ! BGP route filtering for Cilium Pod CIDRs
            ip prefix-list CILIUM_POD_CIDRS permit ${cfg.bgp.podCidr}
            !
            route-map FROM_CILIUM permit 10
             match ip address prefix-list CILIUM_POD_CIDRS
            !
            ! Interface Configuration (Unchanged)
            interface lo
              ip address ${cfg.loopbackAddress.ipv4}
              ip router openfabric 1
              ipv6 address ${cfg.loopbackAddress.ipv6}
              ipv6 router openfabric 1
              openfabric passive
            !
            ${lib.concatMapStringsSep "\n" (interface: ''
              interface ${interface}
                ip router openfabric 1
                ipv6 router openfabric 1
                openfabric csnp-interval 2
                openfabric hello-interval 1
                openfabric hello-multiplier 2
              !'') interfaces}
            !
            ! OpenFabric Router (Phase 1: Still handles host routes)
            router openfabric 1
              net ${cfg.nsap}
              fabric-tier 0
              lsp-gen-interval 1
              max-lsp-lifetime 600
              lsp-refresh-interval 180
              !
              ! MAGIC: Learn BGP routes from Cilium and advertise them via OpenFabric
              redistribute bgp ipv4 route-map FROM_CILIUM
            !
            ! BGP Router (Phase 1: Learns Pod CIDRs from Cilium, peers with other nodes)
            router bgp ${toString cfg.bgp.localAsn}
              bgp router-id ${lib.removeSuffix "/32" cfg.loopbackAddress.ipv4}
              !
              ! Peer with the local Cilium agent
              neighbor 127.0.0.1 remote-as ${toString cfg.bgp.ciliumAsn}
              !
              ! Peer with the other cluster nodes
              ${lib.concatMapStringsSep "\n" (peer: ''
                neighbor ${peer.ip} remote-as ${toString peer.asn}
                neighbor ${peer.ip} update-source lo
              '') cfg.bgp.peers}
              !
              ! Address Family Configuration
              address-family ipv4 unicast
                ! Activate the Cilium neighbor and apply the filter
                neighbor 127.0.0.1 activate
                neighbor 127.0.0.1 route-map FROM_CILIUM in
                !
                ! Activate the cluster node neighbors
                ${lib.concatMapStringsSep "\n" (peer: "neighbor ${peer.ip} activate") cfg.bgp.peers}
              exit-address-family
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
              "21-thunderbolt" = {
                matchConfig.Driver = "thunderbolt-net";
                linkConfig = {
                  ActivationPolicy = "up";
                  MTUBytes = "1500";
                };
                networkConfig = {
                  LinkLocalAddressing = "no";
                };
              };
            };
          };
        };
      };
    };
}
