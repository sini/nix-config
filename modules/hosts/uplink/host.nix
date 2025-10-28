{ ... }:
{
  flake.hosts.uplink = {
    ipv4 = [ "10.10.10.1" ];
    ipv6 = [ "fd64:0:1::1/64" ];
    environment = "prod";
    roles = [
      "server"
      "unlock"
      # "bgp-hub"
      # "inference"
      "metrics-ingester"
    ];
    tags = {
      "bgp-asn" = "65000";
    };
    features = [
      "cpu-amd"
      "gpu-intel"
      "zfs-disk-single"
      "podman"
      #"docker"
      "acme"
      "nginx"
      "kanidm"
      "grafana"
      "ollama"
      "open-webui"
      # "minio"
      # "vault"
    ];
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        boot.kernelPackages = pkgs.linuxPackages_cachyos-server.cachyOverride { mArch = "GENERIC_V4"; };

        hardware = {
          disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
          networking.interfaces = [ "enp4s0" ];
        };

        impermanence = {
          enable = true;
          wipeRootOnBoot = true;
          wipeHomeOnBoot = true;
        };

        system.stateVersion = "25.05";
      };
  };
}
