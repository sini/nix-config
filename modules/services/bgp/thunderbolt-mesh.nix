# Thunderbolt mesh networking with dynamic BGP configuration
# Auto-detects peers and configures topology from host tags
#
# This module provides dynamic thunderbolt mesh networking with BGP peering
# for high-speed inter-node communication. It automatically discovers peer
# nodes based on host tags and creates BGP sessions only for directly
# connected thunderbolt interfaces.
#
# ## Topology
#
# The module supports any thunderbolt mesh topology where nodes are connected
# via point-to-point /31 networks. Common topologies include:
#
# - **2-node**: axon-01 ↔ axon-02
# - **3-node ring**: axon-01 ↔ axon-02 ↔ axon-03 ↔ axon-01
# - **4-node partial mesh**: axon-01 ↔ axon-02 ↔ axon-03 ↔ axon-04
# - **Star topology**: central-hub ↔ spoke-1/2/3
#
# The module automatically detects which peers have direct thunderbolt
# connections and only creates BGP sessions for those pairs.
#
# ## Host Configuration
#
# Each thunderbolt mesh node requires these host tags:
#
# ```nix
# flake.hosts.axon-01 = {
#   roles = [ "server" "bgp-spoke" ];
#   extra_modules = [ thunderbolt-mesh ];
#   tags = {
#     # BGP AS number for this node
#     "bgp-asn" = "65001";
#
#     # Loopback interface for BGP router ID and peering
#     "thunderbolt-loopback-ipv4" = "172.16.255.1/32";
#     "thunderbolt-loopback-ipv6" = "fdb4:5edb:1b00::1/128";
#
#     # Thunderbolt interface IP assignments (/31 networks)
#     "thunderbolt-interface-1" = "169.254.12.0/31";  # connects to axon-02
#     "thunderbolt-interface-2" = "169.254.31.1/31";  # connects to axon-03
#   };
# };
# ```
#
# ## Interface Mapping
#
# The module maps thunderbolt interfaces in a fixed order:
# - `thunderbolt-interface-1` → `enp199s0f5`
# - `thunderbolt-interface-2` → `enp199s0f6`
#
# ## Network Requirements
#
# - All thunderbolt links must use /31 networks for point-to-point connections
# - Each /31 network should connect exactly two nodes
# - Loopback addresses must be unique across the mesh
# - BGP AS numbers should be unique per node
#
# ## BGP Configuration
#
# The module automatically creates:
# - BGP peering sessions using loopback IPs as next-hops
# - Static routes to peer loopback and LAN IPs via thunderbolt gateways
# - eBGP multihop configuration for loopback-to-loopback peering
# - Route advertisement for the local loopback network
#
# ## Example 3-Node Ring Setup
#
# ```nix
# # Node 1: connects to nodes 2 and 3
# flake.hosts.axon-01.tags = {
#   "bgp-asn" = "65001";
#   "thunderbolt-loopback-ipv4" = "172.16.255.1/32";
#   "thunderbolt-interface-1" = "169.254.12.0/31";  # → axon-02
#   "thunderbolt-interface-2" = "169.254.31.1/31";  # → axon-03
# };
#
# # Node 2: connects to nodes 3 and 1
# flake.hosts.axon-02.tags = {
#   "bgp-asn" = "65002";
#   "thunderbolt-loopback-ipv4" = "172.16.255.2/32";
#   "thunderbolt-interface-1" = "169.254.23.0/31";  # → axon-03
#   "thunderbolt-interface-2" = "169.254.12.1/31";  # → axon-01
# };
#
# # Node 3: connects to nodes 1 and 2
# flake.hosts.axon-03.tags = {
#   "bgp-asn" = "65003";
#   "thunderbolt-loopback-ipv4" = "172.16.255.3/32";
#   "thunderbolt-interface-1" = "169.254.31.0/31";  # → axon-01
#   "thunderbolt-interface-2" = "169.254.23.1/31";  # → axon-02
# };
# ```
#
# ## Peer Discovery Algorithm
#
# 1. Find all hosts in the same environment with `thunderbolt-loopback-ipv4` tags
# 2. For each potential peer, check if any of our interfaces form a /31 pair
#    with any of their interfaces
# 3. Create BGP sessions only for directly connected peers
# 4. Filter out peers with no direct thunderbolt connection
#
# This ensures the module works correctly with partial meshes, broken links,
# or any arbitrary thunderbolt topology.
{
  config,
  lib,
  ...
}:
let
  # Helper to get hosts with thunderbolt-mesh module in the same environment
  getThunderboltPeers =
    currentHostEnvironment: currentHostname:
    lib.filterAttrs (
      name: host:
      name != currentHostname
      && host.tags ? "thunderbolt-loopback-ipv4"
      && host.environment == currentHostEnvironment
    ) config.flake.hosts;
in
{
  flake.modules.nixos.thunderbolt-mesh =
    {
      lib,
      config,
      hostOptions,
      ...
    }:
    let
      interfaces = [
        "enp199s0f5"
        "enp199s0f6"
      ];

      # Auto-discover peer configuration from host settings
      thunderboltPeers = getThunderboltPeers hostOptions.environment config.networking.hostName;

      # Derive gateway IPs from peer interface assignments
      # This logic determines which interface connects to which peer by checking /31 network pairs
      getGatewayForPeer =
        peerHostname: peerLoopbackIp:
        let
          peerHost = thunderboltPeers.${peerHostname};

          # Get our own interface IPs
          ourInterface1 = hostOptions.tags."thunderbolt-interface-1";
          ourInterface2 = hostOptions.tags."thunderbolt-interface-2";

          # Get peer's interface IPs
          peerInterface1 = peerHost.tags."thunderbolt-interface-1";
          peerInterface2 = peerHost.tags."thunderbolt-interface-2";

          # Check if two IPs are in the same /31 network
          sameNetwork =
            ip1: ip2:
            let
              parts1 = lib.splitString "/" ip1;
              parts2 = lib.splitString "/" ip2;
              baseIp1 = lib.head parts1;
              baseIp2 = lib.head parts2;
              # For /31 networks, the base addresses should differ by exactly 1 in the last octet
              ipParts1 = lib.splitString "." baseIp1;
              ipParts2 = lib.splitString "." baseIp2;
              prefix1 = lib.concatStringsSep "." (lib.init ipParts1);
              prefix2 = lib.concatStringsSep "." (lib.init ipParts2);
              lastOctet1 = lib.toInt (lib.last ipParts1);
              lastOctet2 = lib.toInt (lib.last ipParts2);
            in
            prefix1 == prefix2
            &&
              (
                let
                  diff = lastOctet1 - lastOctet2;
                in
                if diff < 0 then -diff else diff
              ) == 1;

          # Extract the gateway IP from peer's interface that connects to us
          extractGateway =
            interfaceIp:
            let
              parts = lib.splitString "/" interfaceIp;
              baseIp = lib.head parts;
            in
            baseIp;
        in
        # Find which peer interface is in the same /31 network as one of our interfaces
        # Return null if no direct connection exists
        if sameNetwork ourInterface1 peerInterface1 then
          extractGateway peerInterface1
        else if sameNetwork ourInterface1 peerInterface2 then
          extractGateway peerInterface2
        else if sameNetwork ourInterface2 peerInterface1 then
          extractGateway peerInterface1
        else if sameNetwork ourInterface2 peerInterface2 then
          extractGateway peerInterface2
        else
          null; # No direct connection to this peer

      # Generate peer configurations from discovered hosts, only for directly connected peers
      peerConfigs = lib.filter (peer: peer.gateway != null) (
        map (
          peerHostname:
          let
            peerHost = thunderboltPeers.${peerHostname};
            peerLoopbackIp = lib.removeSuffix "/32" (peerHost.tags."thunderbolt-loopback-ipv4");
            gateway = getGatewayForPeer peerHostname peerLoopbackIp;
          in
          {
            asn = lib.toInt (peerHost.tags."bgp-asn");
            lanip = peerHost.ipv4;
            ip = peerLoopbackIp;
            gateway = gateway;
          }
        ) (lib.attrNames thunderboltPeers)
      );

      # Current node configuration from tags
      nodeConfig = {
        loopback = {
          ipv4 = hostOptions.tags."thunderbolt-loopback-ipv4";
          ipv6 = hostOptions.tags."thunderbolt-loopback-ipv6";
        };
        interfaceIps = {
          enp199s0f5 = hostOptions.tags."thunderbolt-interface-1";
          enp199s0f6 = hostOptions.tags."thunderbolt-interface-2";
        };
        peers = peerConfigs;
      };
    in
    {
      imports = [ ./_module/bgp.nix ];

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

        services.bgp = {
          localAsn = if hostOptions.tags ? "bgp-asn" then lib.toInt hostOptions.tags."bgp-asn" else 65001;
          routerId = lib.removeSuffix "/32" nodeConfig.loopback.ipv4;

          staticRoutes = lib.flatten (
            map (peer: [
              "ip route ${peer.ip}/32 ${peer.gateway}"
              "ip route ${peer.lanip}/32 ${peer.gateway}"
            ]) nodeConfig.peers
          );

          neighbors = map (peer: {
            ip = peer.ip;
            asn = peer.asn;
            updateSource = "dummy0";
            ebgpMultihop = 4;
            softReconfiguration = true;
            allowasIn = 1;
          }) nodeConfig.peers;

          addressFamilies.ipv4-unicast = {
            networks = [ nodeConfig.loopback.ipv4 ];
            neighbors = lib.listToAttrs (
              map (
                peer:
                lib.nameValuePair peer.ip {
                  activate = true;
                  nextHopSelf = true;
                }
              ) nodeConfig.peers
            );
          };
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
