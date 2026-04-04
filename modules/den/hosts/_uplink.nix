{
  den,
  rootPath,
  ...
}:
{
  den.hosts.x86_64-linux.uplink = {
    environment = "prod";
    system-access-groups = [ "server-access" ];
    networking.interfaces.enp4s0 = {
      ipv4 = [ "10.10.10.1/16" ];
      ipv6 = [ "fe80::3c7a:6eff:fee5:d3a6" ];
    };
    facts = ../../hosts/uplink/facter.json;
    public_key = rootPath + "/.secrets/hosts/uplink/ssh_host_ed25519_key.pub";

    settings = {
      bgp.localAsn = 65000;
      zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
      impermanence.wipeHomeOnBoot = true;
    };
  };

  den.aspects.uplink = {
    includes = [
      den.aspects.default
      # Disk
      den.aspects.zfs-disk-single
      den.aspects.impermanence-zfs
      den.aspects.zfs-diff
      # Roles
      den.aspects.server
      den.aspects.unlock
      den.aspects.nix-builder
      den.aspects.metrics-ingester
      den.aspects.headscale
      den.aspects.inference
      # Hardware
      den.aspects.cpu-amd
      den.aspects.gpu-intel
      # Network
      den.aspects.bgp-hub
      den.aspects.tailscale
      # Services
      den.aspects.acme
      den.aspects.nginx
      den.aspects.kanidm
      den.aspects.grafana
      den.aspects.open-webui
      den.aspects.jellyfin
      den.aspects.homepage
      den.aspects.oauth2-proxy
      den.aspects.haproxy
      den.aspects.attic-server
      # Runtime
      den.aspects.podman
    ];
  };
}
