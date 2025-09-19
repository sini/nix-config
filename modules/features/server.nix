#
{
  flake.modules.nixos.server = {
    # Enable Prometheus node exporter for monitoring
    services.prometheus.exporters.node = {
      enable = true;
      port = 9100;
      listenAddress = "0.0.0.0"; # Allow remote scraping
      enabledCollectors = [
        "processes"
        "interrupts"
        "ksmd"
        "logind"
        "meminfo_numa"
        "mountstats"
        "network_route"
        "systemd"
        "tcpstat"
        "wifi"
      ];
    };

    # Open firewall for node exporter
    networking.firewall.allowedTCPPorts = [ 9100 ];

    # Servers don't sleep
    systemd.sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
      AllowHybridSleep=no
      AllowSuspendThenHibernate=no
    '';
    systemd.targets.hibernate.enable = false;
    systemd.targets.hybrid-sleep.enable = false;

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
      "net.ipv6.conf.all.forwarding" = true;
      "net.netfilter.nf_conntrack_max" = 131072;
      "net.nf_conntrack_max" = 131072;
      "net.ipv4.ip_forward" = 1;
      "net.ipv4.conf.all.proxy_arp" = false; # Was true, default is false and we don't want to poison our external network
      # Bridge settings for optimal switching performance
      "net.bridge.bridge-nf-call-iptables" = 0;
      "net.bridge.bridge-nf-call-ip6tables" = 0;
      "net.bridge.bridge-nf-call-arptables" = 0;
      # These need to be increased for k8s
      # Although the default settings might not cause issues initially, you'll get strange behavior after a while
      "fs.inotify.max_user_instances" = 1048576;
      "fs.inotify.max_user_watches" = 1048576;
    };
  };
}
