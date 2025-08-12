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
        "tb1"
        "tb2"
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
            lsp-refresh-interval 180'';
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
                  Name = "enp0s13f3";
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
                  Name = "enp0s13f2";
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
