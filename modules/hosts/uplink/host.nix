{ config, ... }:
{
  flake.hosts.uplink = {
    ipv4 = [ "10.10.10.1" ];
    ipv6 = [ "fd64:0:1::1/64" ];
    environment = "prod";
    roles = [
      "server"
      "bgp-hub"
      "metrics-ingester"
    ];
    tags = {
      "bgp-asn" = "65000";
    };
    extra_modules = with config.flake.modules.nixos; [
      cpu-amd
      gpu-intel
      disk-single
      podman
      acme
      nginx
      kanidm
      grafana
      # minio
      # vault
    ];
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9Q/KHuuigi5EU8I36EQQzw4QCXj3dEh0bzz/uZ1y+p";
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        hardware = {
          disk.single.device_id = "nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
          networking = {
            interfaces = [ "enp10s0" ];
            unmanagedInterfaces = [
              # "enp10s0"
              # "enp10s0d1"
              # "br0"
            ];
          };
        };

        # boot.kernelModules = [ "br_netfilter" ];
        # boot.kernel.sysctl = {
        #   # Bridge settings - disable netfilter calls for transparent bridging
        #   # This allows bridge traffic to bypass iptables while host traffic is still filtered
        #   "net.bridge.bridge-nf-call-iptables" = 0;
        #   "net.bridge.bridge-nf-call-ip6tables" = 0;
        #   "net.bridge.bridge-nf-call-arptables" = 0;
        # };
        # systemd.network = {
        #   netdevs = {
        #     "10-br0" = {
        #       netdevConfig = {
        #         Kind = "bridge";
        #         Name = "br0";
        #       };
        #     };
        #   };

        #   networks = {
        #     "30-enp10s0" = {
        #       enable = true;
        #       matchConfig.Name = "enp10s0";
        #       networkConfig.Bridge = "br0";
        #       linkConfig.RequiredForOnline = "enslaved";
        #     };

        #     "30-enp10s0d1" = {
        #       enable = true;
        #       matchConfig.Name = "enp10s0d1";
        #       networkConfig.Bridge = "br0";
        #       linkConfig.RequiredForOnline = "enslaved";
        #     };

        #     "40-br0" = {
        #       enable = true;
        #       matchConfig.Name = "br0";
        #       networkConfig = {
        #         DHCP = "ipv6"; # Enable DHCPv6 for prefix delegation
        #         IPv6AcceptRA = true;
        #         IPv6SendRA = false;
        #       };
        #       dhcpV6Config = {
        #         UseDelegatedPrefix = true;
        #         PrefixDelegationHint = "::/60"; # Request /60 for multiple subnets
        #         WithoutRA = "solicit"; # Request delegation even without RA
        #       };
        #       ipv6AcceptRAConfig = {
        #         UseDNS = true;
        #         DHCPv6Client = "always";
        #       };
        #       address = [
        #         "10.10.10.1/16"
        #         "fd64:0:1::1/64"
        #       ];
        #       routes = [
        #         { Gateway = environment.gatewayIp; }
        #       ];
        #       dns = environment.dnsServers;
        #       linkConfig.RequiredForOnline = "routable";
        #       extraConfig = ''
        #         [DHCPv6]
        #         UseDelegatedPrefix=true
        #         PrefixDelegationHint=::/60
        #       '';
        #     };
        #   };
        # };
        boot.kernelPackages = pkgs.linuxPackages_latest;
        system.stateVersion = "25.05";

      };
  };
}
