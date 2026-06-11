{ den, ... }:
{
  den.hosts.x86_64-linux.uplink = {
    channel = "nixpkgs-master";
    environment = "prod";
    system-owner = "sini";
    system-access-groups = [ "server-access" ];

    networking.interfaces.enp4s0 = {
      ipv4 = [ "10.10.10.1/16" ];
      ipv6 = [ "fe80::3c7a:6eff:fee5:d3a6" ];
    };

    settings = {
      services.bgp.localAsn = 65000;
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
      core.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = true;
      };
    };
  };

  den.aspects.uplink = {
    includes = with den.aspects; [
      roles.default
      core.boot.network-initrd
      disk.zfs-disk-single
      roles.server
      roles.unlock
      roles.nix-builder
      roles.metrics-ingester
      services.bgp.hub
      services.networking.headscale
      services.security.acme
      services.networking.nginx
      services.security.kanidm
      services.networking.haproxy
      services.media.jellyfin
      services.web.homepage
      services.security.oauth2-proxy
      services.ai.ollama
      services.ai.open-webui
      services.nix.attic
      core.network.tailscale
      services.web.den-docs-mirror
      services.web.container-registry
      services.monitoring.grafana
      virtualization.podman
      hardware.cpu.amd
      hardware.gpu.intel
    ];
  };
}
