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
          enable = lib.mkEnableOption "BGP peering with the uplink machine";

          asn = lib.mkOption {
            type = lib.types.int;
            default = 65001;
            description = "Autonomous System Number for the internal network.";
          };

          uplinkPeerIp = lib.mkOption {
            type = lib.types.str;
            example = "10.10.10.1";
            description = "The Ethernet IP address of the uplink machine.";
          };

          serviceVip = lib.mkOption {
            type = lib.types.str;
            example = "10.10.11.1/32";
            description = "The virtual IP to advertise for cluster services.";
          };
        };
      };

      config = {
        hardware.networking.unmanagedInterfaces = interfaces;

        boot = {
          kernelParams = [
            "pcie=pcie_bus_perf"
          ];
          kernel.sysctl = {
            "net.ipv4.ip_forward" = 1;
            "net.ipv4.conf.all.proxy_arp" = true;
            "net.ipv6.conf.all.forwarding" = 1;
            # These need to be increased for k8s
            # Although the default settings might not cause issues initially, you'll get strange behavior after a while
            "fs.inotify.max_user_instances" = 1048576;
            "fs.inotify.max_user_watches" = 1048576;
          };
          kernelModules = [
            "thunderbolt"
            "thunderbolt-net"
          ];
        };

        services.frr = {
          fabricd.enable = true;
          config = ''
            ip forwarding
            ipv6 forwarding
            !
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
            router openfabric 1
            net ${cfg.nsap}
            fabric-tier 0
            lsp-gen-interval 1
            max-lsp-lifetime 600
            lsp-refresh-interval 180
          ''
          + lib.mkIf cfg.bgp.enable ''
            !
            ! BGP Configuration for Uplink Peering
            !
            router bgp ${toString cfg.bgp.asn}
              bgp router-id ${lib.removeSuffix "/32" cfg.loopbackAddress.ipv4}
              neighbor ${cfg.bgp.uplinkPeerIp} remote-as ${toString cfg.bgp.asn}
              !
              address-family ipv4 unicast
                network ${cfg.bgp.serviceVip}
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
