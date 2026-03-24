# Thunderbolt mesh networking with BGP peering.
#
# Auto-discovers peers in the same environment and creates BGP sessions
# for directly connected /31 point-to-point thunderbolt links.
# Physical ports map in order: interfaces[0] → enp199s0f5, [1] → enp199s0f6.
#
# Settings:
#   thunderbolt-mesh.interfaces - list of /31 CIDRs per physical port
#   bgp.localAsn               - node's AS number (from bgp feature)
{ lib, ... }:
{
  features.thunderbolt-mesh = {
    requires = [ "bgp" ];

    settings = {
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          Thunderbolt interface IP assignments (CIDR notation, /31 point-to-point).
          Ordered by physical port: index 0 → enp199s0f5, index 1 → enp199s0f6.
        '';
        example = [
          "169.254.12.0/31"
          "169.254.31.1/31"
        ];
      };
    };

    linux =
      {
        lib,
        config,
        environment,
        host,
        settings,
        ...
      }:
      let
        cfg = settings.thunderbolt-mesh;

        physicalInterfaces = [
          "enp199s0f5"
          "enp199s0f6"
        ];

        # Auto-discover peer configuration from host settings
        thunderboltPeers = lib.filterAttrs (name: _host: name != config.networking.hostName) (
          environment.findHostsByFeature "thunderbolt-mesh"
        );

        # Derive gateway IPs from peer interface assignments
        # This logic determines which interface connects to which peer by checking /31 network pairs
        getGatewayForPeer =
          peerHostname: _peerLoopbackIp:
          let
            peerHost = thunderboltPeers.${peerHostname};

            # Get our own interface IPs
            ourInterface1 = lib.elemAt cfg.interfaces 0;
            ourInterface2 = lib.elemAt cfg.interfaces 1;

            # Get peer's interface IPs
            peerCfg = peerHost.feature-settings.thunderbolt-mesh.interfaces;
            peerInterface1 = lib.elemAt peerCfg 0;
            peerInterface2 = lib.elemAt peerCfg 1;

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
              peerLoopbackIp = builtins.head peerHost.ipv4;
              gateway = getGatewayForPeer peerHostname peerLoopbackIp;
            in
            {
              asn = peerHost.feature-settings.bgp.localAsn;
              lanip = builtins.head peerHost.ipv4;
              ip = peerLoopbackIp;
              inherit gateway;
            }
          ) (lib.attrNames thunderboltPeers)
        );

        # Current node configuration from settings
        nodeConfig = {
          loopback = {
            ipv4 = builtins.head host.ipv4;
          };
          interfaceIps = lib.listToAttrs (
            lib.imap0 (i: dev: lib.nameValuePair dev (lib.elemAt cfg.interfaces i)) physicalInterfaces
          );
          peers = peerConfigs;
        };
      in
      {
        config = {
          boot = {
            kernelParams = [
              "pcie=pcie_bus_perf"
            ];
            kernelModules = [
              "thunderbolt"
              "thunderbolt-net"
            ];
          };

          services.bgp = {
            staticRoutes = lib.flatten (
              map (peer: [
                "ip route ${peer.lanip}/32 ${peer.gateway}"
              ]) nodeConfig.peers
            );

            neighbors = map (peer: {
              # ip = peer.ip;
              ip = peer.gateway;
              inherit (peer) asn;
              ebgpMultihop = 4;
              softReconfiguration = true;
              allowasIn = 1;
            }) nodeConfig.peers;

            addressFamilies.ipv4-unicast = {
              networks = [ "${nodeConfig.loopback.ipv4}/32" ];
              neighbors = lib.listToAttrs (
                map (
                  peer:
                  lib.nameValuePair peer.gateway {
                    activate = true;
                    # nextHopSelf = true;
                  }
                ) nodeConfig.peers
              );
            };
          };

          systemd = {
            services = {
              frr = {
                requires = lib.lists.forEach physicalInterfaces (i: "sys-subsystem-net-devices-${i}.device");
                after = lib.lists.forEach physicalInterfaces (i: "sys-subsystem-net-devices-${i}.device");
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
                "21-thunderbolt-1" = {
                  matchConfig.Name = "enp199s0f5";
                  address = [ nodeConfig.interfaceIps.enp199s0f5 ];
                  linkConfig = {
                    ActivationPolicy = "up";
                    # MTUBytes = "9000"; # Recommended for performance
                    MTUBytes = 1500; # for compat
                  };
                  networkConfig.LinkLocalAddressing = "no";
                };
                "21-thunderbolt-2" = {
                  matchConfig.Name = "enp199s0f6";
                  address = [ nodeConfig.interfaceIps.enp199s0f6 ];
                  linkConfig = {
                    ActivationPolicy = "up";
                    # MTUBytes = "9000"; # Recommended for performance
                    MTUBytes = 1500; # for compat
                  };
                  networkConfig.LinkLocalAddressing = "no";
                };
              };
            };
          };
        };
      };
  };
}
