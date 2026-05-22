{ den, ... }:
{
  den.hosts.x86_64-linux.uplink = {
    channel = "nixos-unstable";
    environment = "prod";

    networking.interfaces.enp4s0 = {
      ipv4 = [ "10.10.10.1/16" ];
      ipv6 = [ "fe80::3c7a:6eff:fee5:d3a6" ];
    };

    settings = {
      services.bgp.localAsn = 65000;
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
      disk.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = true;
      };
    };
  };

  den.aspects.uplink = {
    includes = with den.aspects; [
      core.default
      secrets.agenix
      networking
      network.openssh
      network.network-boot
      disk.zfs-disk-single
      disk.impermanence
      roles.server
      roles.unlock
      roles.nix-builder
      roles.metrics-ingester
      services.bgp.hub
      services.headscale
      services.acme
      services.nginx
      services.kanidm
      services.haproxy
      services.jellyfin
      services.homepage
      services.oauth2-proxy
      services.ollama
      services.open-webui
      services.attic
      services.tailscale
      services.den-docs-mirror
      hardware.cpu-amd
      hardware.gpu-intel
    ];
  };
}
