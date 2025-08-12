{
  flake.modules.nixos.thunderbolt-mesh = {
    hardware.networking.unmanagedInterfaces = [
      "tb01"
      "tb02"
    ];

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

    systemd.network = {
      config.networkConfig = {
        IPv4Forwarding = true;
        IPv6Forwarding = true;
      };

      links = {
        "50-tb01" = {
          matchConfig = {
            Path = "pci-0000:c7:00.5";
            Driver = "thunderbolt-net";
          };
          linkConfig = {
            MACAddressPolicy = "none";
            Name = "tb01";
          };
        };
        "50-tb02" = {
          matchConfig = {
            Path = "pci-0000:c7:00.6";
            Driver = "thunderbolt-net";
          };
          linkConfig = {
            MACAddressPolicy = "none";
            Name = "tb02";
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
}
