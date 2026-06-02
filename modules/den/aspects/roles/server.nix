{ den, lib, ... }:
{
  den.aspects.roles.server = {
    colmena = [ "server" ];
    includes = with den.aspects; [
      services.security.acme
      services.security.tang
      services.storage.media-data-share
      services.monitoring.prometheus-exporter
      core.boot.network-initrd
    ];

    nixos = _: {
      systemd.targets =
        lib.genAttrs
          [
            "sleep"
            "suspend"
            "hibernate"
            "hybrid-sleep"
          ]
          (_: {
            enable = false;
            unitConfig.DefaultDependencies = false;
          });

      boot.kernel.sysctl = {
        "net.core.rmem_default" = 1048576;
        "net.core.wmem_default" = 1048576;
        "net.core.rmem_max" = 134217728;
        "net.core.wmem_max" = 134217728;
        "net.core.netdev_max_backlog" = 50000;
        "net.core.netdev_budget" = 1000;
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.ipv4.route.max_size" = 524288;
        "net.ipv4.tcp_fastopen" = "3";
        "net.ipv4.ip_forward" = 1;
        "net.ipv4.conf.all.forwarding" = 1;
        "net.ipv6.conf.all.forwarding" = 1;

        "net.netfilter.nf_conntrack_max" = 131072;
        "net.nf_conntrack_max" = 131072;
        "fs.inotify.max_user_instances" = 1048576;
        "fs.inotify.max_user_watches" = 1048576;
      };
    };
  };
}
