# Thunderbolt mesh networking with BGP peering.
#
# Auto-discovers peers in the same environment and creates BGP sessions
# for directly connected /31 point-to-point thunderbolt links.
# Interface IPs come from host.networking.interfaces (managed = false).
# Link renaming (PCI path → device name) is handled here.
{
  features.thunderbolt-mesh = {
    requires = [ "bgp" ];

    linux =
      {
        lib,
        config,
        environment,
        host,
        ...
      }:
      let
        physicalInterfaces = [
          "enp199s0f5"
          "enp199s0f6"
        ];

        # Read interface IPs from host networking
        getIfaceIp = dev: lib.head (host.networking.interfaces.${dev}.ipv4 or [ ]);

        # Auto-discover peer configuration from host settings
        thunderboltPeers = lib.filterAttrs (name: _host: name != config.networking.hostName) (
          environment.findHostsByFeature "thunderbolt-mesh"
        );

        # Derive gateway IPs from peer interface assignments
        # Determines which interface connects to which peer by checking /31 network pairs
        getGatewayForPeer =
          peerHostname: _peerLoopbackIp:
          let
            peerHost = thunderboltPeers.${peerHostname};

            # Get our own interface IPs
            ourInterface1 = getIfaceIp "enp199s0f5";
            ourInterface2 = getIfaceIp "enp199s0f6";

            # Get peer's interface IPs
            peerInterface1 = lib.head (peerHost.networking.interfaces.enp199s0f5.ipv4 or [ ]);
            peerInterface2 = lib.head (peerHost.networking.interfaces.enp199s0f6.ipv4 or [ ]);

            # Check if two IPs are in the same /31 network
            sameNetwork =
              ip1: ip2:
              let
                baseIp1 = lib.head (lib.splitString "/" ip1);
                baseIp2 = lib.head (lib.splitString "/" ip2);
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

            extractGateway = interfaceIp: lib.head (lib.splitString "/" interfaceIp);
          in
          if sameNetwork ourInterface1 peerInterface1 then
            extractGateway peerInterface1
          else if sameNetwork ourInterface1 peerInterface2 then
            extractGateway peerInterface2
          else if sameNetwork ourInterface2 peerInterface1 then
            extractGateway peerInterface1
          else if sameNetwork ourInterface2 peerInterface2 then
            extractGateway peerInterface2
          else
            null;

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

        nodeConfig = {
          loopback.ipv4 = builtins.head host.ipv4;
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
                  }
                ) nodeConfig.peers
              );
            };
          };

          systemd = {
            services.frr = {
              requires = lib.lists.forEach physicalInterfaces (i: "sys-subsystem-net-devices-${i}.device");
              after = lib.lists.forEach physicalInterfaces (i: "sys-subsystem-net-devices-${i}.device");
            };

            network = {
              config.networkConfig = {
                IPv4Forwarding = true;
                IPv6Forwarding = true;
              };

              # Link renaming: PCI path → stable device names
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

              # Network config is now generated by networking.nix from host.networking.interfaces
            };
          };
        };
      };
  };
}
