{
  hosts.uplink = {
    networking.interfaces.enp4s0 = {
      ipv4 = [ "10.10.10.1" ];
      ipv6 = [ "fe80::3c7a:6eff:fee5:d3a6" ];
    };
    remoteBuildSpeed = 10;
    remoteBuildJobs = 16;
    environment = "prod";
    roles = [
      "server"
      "unlock"
      "bgp-hub"
      # "inference"
      "metrics-ingester"
      "nix-builder"
      "headscale"
    ];
    tags = {
      "bgp-asn" = "65000";
    };
    extra-features = [
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
      "jellyfin"
      # TODO: ehhh
      "homepage"
      "oauth2-proxy"
      "tailscale"
      "haproxy"
      "attic-server"
      # "minio"
      # "vault"
    ];
    facts = ./facter.json;
    systemConfiguration =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-server-lto;

        hardware = {
          disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
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
