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
          kernelModules = [
            "thunderbolt"
            "thunderbolt-net"
          ];
        };

        services.frr = {
          bgpd.enable = true;
          config = ''
            !
            ! Static routes to bootstrap iBGP peering over loopbacks.
            ! These are generated automatically from your 'peers' data.
            ${lib.concatMapStringsSep "\n" (peer: ''
              ip route ${peer.ip}/32 ${peer.gateway}
            '') cfg.bgp.peers}
            !
            ! Main BGP configuration
            !
            router bgp ${toString cfg.bgp.localAsn}
              no bgp ebgp-requires-policy
              bgp bestpath as-path multipath-relax
              bgp router-id ${lib.removeSuffix "/32" cfg.loopbackAddress.ipv4}
              !
              neighbor CILIUM peer-group
              neighbor CILIUM remote-as ${toString cfg.bgp.ciliumAsn}
              ! bgp listen range 192.168.2.0/24 peer-group CILIUM
              ! bgp listen range 10.5.0.0/16 peer-group CILIUM
              bgp listen range 172.20.0.0/16 peer-group CILIUM
              ! bgp listen range 2001:db8:1::/64 peer-group CILIUM
              ! == Peer with the local Cilium agent (eBGP) ==
              neighbor 127.0.0.1 remote-as ${toString cfg.bgp.ciliumAsn}
              ! == Peer with other cluster nodes (iBGP) using their stable loopbacks ==
              ${lib.concatMapStringsSep "\n" (peer: ''
                neighbor ${peer.ip} remote-as ${toString cfg.bgp.localAsn}
                neighbor ${peer.ip} update-source lo
                neighbor ${peer.ip} soft-reconfiguration inbound
              '') cfg.bgp.peers}
              !
              ! Address Family configuration for IPv4
              address-family ipv4 unicast
                ! Advertise this node's own loopback to its iBGP peers
                network ${cfg.loopbackAddress.ipv4}
                redistribute connected
                redistribute static
                !
                ! Activate the Cilium neighbor
                neighbor CILIUM activate
                neighbor 127.0.0.1 activate
                !
                ! Activate the iBGP peers and set next-hop-self.
                ! 'next-hop-self' is CRITICAL for routes from Cilium to work.
                ${lib.concatMapStringsSep "\n" (peer: ''
                  neighbor ${peer.ip} activate
                  neighbor ${peer.ip} route-map ALLOW-ALL in
                  neighbor ${peer.ip} route-map ALLOW-ALL out
                  neighbor ${peer.ip} next-hop-self
                '') cfg.bgp.peers}
              exit-address-family
              !
              route-map ALLOW-ALL permit 10
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
