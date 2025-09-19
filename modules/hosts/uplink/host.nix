{ config, ... }:
{
  flake.hosts.uplink = {
    ipv4 = [ "10.10.10.1" ];
    ipv6 = [ "2001:5a8:608c:4a00::1/64" ];
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
  };

  flake.modules.nixos.host_uplink =
    {
      pkgs,
      ...
    }:
    {
      hardware = {
        disk.single.device_id = "nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
        networking = {
          interfaces = [ ];
          unmanagedInterfaces = [
            "enp10s0"
            "enp10s0d1"
            "br0"
          ];
        };
      };

      systemd.network = {
        netdevs = {
          "10-br0" = {
            netdevConfig = {
              Kind = "bridge";
              Name = "br0";
            };
          };
        };

        networks = {
          "30-enp10s0" = {
            enable = true;
            matchConfig.Name = "enp10s0";
            networkConfig.Bridge = "br0";
            linkConfig.RequiredForOnline = "enslaved";
          };

          "30-enp10s0d1" = {
            enable = true;
            matchConfig.Name = "enp10s0d1";
            networkConfig.Bridge = "br0";
            linkConfig.RequiredForOnline = "enslaved";
          };

          "40-br0" = {
            enable = true;
            matchConfig.Name = "br0";
            networkConfig = {
              IPv6AcceptRA = true;
              IPv6SendRA = false;
            };
            dhcpV6Config = {
              UseDelegatedPrefix = true;
              PrefixDelegationHint = "::/64";
            };
            ipv6AcceptRAConfig = {
              UseDNS = true;
              DHCPv6Client = "always";
            };
            address = [
              "10.10.10.1/24"
              "2001:5a8:608c:4a00::1/64"
            ];
            linkConfig.RequiredForOnline = "routable";
            extraConfig = ''
              [DHCPv6]
              UseDelegatedPrefix=true
              PrefixDelegationHint=::/64
            '';
          };
        };
      };
      boot.kernelPackages = pkgs.linuxPackages_latest;
      system.stateVersion = "25.05";

    };
}
