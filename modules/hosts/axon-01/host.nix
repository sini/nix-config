{
  hosts.axon-01 = {
    environment = "prod";
    networking = {
      interfaces.enp2s0 = {
        ipv4 = [ "10.10.10.2" ];
        ipv6 = [ "fe80::40d7:8aff:fe8e:fee4" ];
      };
      unmanagedInterfaces = [
        "enp199s0f5"
        "enp199s0f6"
      ];
    };
    extra-features = [
      # Composite features (formerly roles)
      "server"
      "unlock"
      "k3s"
      "bgp-spoke"
      "nix-builder"
      "thunderbolt-mesh"

      # Hardware and system features
      "zfs-disk-single"
      "xfs-disk-longhorn"
      "cpu-amd"
      "gpu-amd"
      "cilium-bgp"
    ];
    feature-settings.bgp.localAsn = 65001;
    feature-settings.cilium-bgp.localAsn = 65010;
    feature-settings.thunderbolt-mesh.interfaces = [
      "169.254.12.0/31"
      "169.254.31.1/31"
    ];
    feature-settings.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_00230650035M";
    feature-settings.xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
    feature-settings.impermanence.wipeHomeOnBoot = true;

    facts = ./facter.json;
    systemConfiguration =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-server-lto;

        system.stateVersion = "25.05";
      };
  };
}
