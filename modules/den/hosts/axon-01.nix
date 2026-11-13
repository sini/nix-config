{ den, lib, ... }:
let
  plan = import ../schema/_address-plan.nix { inherit lib; };
in
{
  den.hosts.x86_64-linux.axon-01 = {
    channel = "nixos-unstable";
    environment = "prod";
    system-owner = "sini";
    system-access-groups = [ "server-access" ];

    networking.interfaces = {
      enp2s0 = {
        ipv4 = [ "10.10.10.2/16" ];
        ipv6 = [ "fe80::40d7:8aff:fe8e:fee4" ];
        # Deterministic IPv6 egress: one GUA, the token's (SLAAC on the router's
        # prefix, no DHCPv6 lease, no rotating privacy temps), so the node sources
        # from, and Cilium masquerades pods to, the same warm address.
        privacyExtensions = "no";
        # The NIC's own address (ip link, 2026-11-11): the key of its DHCP reservation.
        mac = "58:47:ca:79:e8:e2";
      };
      enp199s0f5 = { };
      enp199s0f6 = { };
    };

    settings = {
      # Kubernetes node (~47 of 62 GB held by pods): builds offload to the remote builders, so
      # local builds stay small and the daemon slice fits the headroom the pods leave.
      core.nix = {
        maxJobs = 1;
        cores = 4;
        daemonMemoryHigh = "12%";
        daemonMemoryMax = "20%";
      };
      services.bgp.localAsn = 65001;
      services.bgp.cilium-bgp.localAsn = 65010;
      services.k3s.clusterName = "axon";
      # gVisor (runsc) on this node only, until the eval sandbox is proven here.
      services.k3s.gvisor = true;
      services.networking.thunderbolt-mesh-of = {
        interfaces = [
          "enp199s0f5"
          "enp199s0f6"
        ];
        loopback.ipv4 = "172.16.255.1/32";
        # Fabric v6 loopbacks: <cluster ULA>:ff::/80, beside pods :1::/96 and
        # services :8001::/112 (clusters/axon.nix, docs/address-plan.md §2.1).
        loopback.ipv6 = "${plan.clusterUla den.environments.prod.ipv6Nibble}:ff::1/128";
        nsap = "49.0000.0000.0001.00";
      };
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_00230650035M";
      disk.xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
      core.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = true;
      };
    };
  };

  den.aspects.axon-01 = {
    # The 500 MB ESP holds 5 generations of this host's 84 MB initrd with no room
    # for a sixth, so a deploy failed "No space left on device" (2026-11-12).
    nixos.boot.loader.systemd-boot.configurationLimit = 3;
    includes = with den.aspects; [
      roles.default
      core.boot.network-initrd
      disk.zfs-disk-single
      disk.xfs-disk-longhorn
      roles.server
      roles.unlock
      # Not a remote builder: a Kubernetes node whose pods hold most of its memory.
      services.bgp.spoke
      services.bgp.cilium-bgp
      services.k3s
      services.storage.media-scratch
      hardware.cpu.amd
      hardware.gpu.amd
      services.networking.thunderbolt-mesh-of
    ];
  };
}
