{ den, ... }:
{
  den.hosts.x86_64-linux.axon-02 = {
    channel = "nixos-unstable";
    environment = "prod";
    system-owner = "sini";
    system-access-groups = [ "server-access" ];

    networking.interfaces = {
      enp2s0 = {
        ipv4 = [ "10.10.10.3/16" ];
        ipv6 = [ "fe80::24d8:31ff:fe26:e771" ];
        # Deterministic IPv6 egress: a single GUA from DHCPv6 only — no SLAAC
        # autoconf, no rotating privacy temps — so the node sources from, and
        # Cilium masquerades pods to, the same warm address (return traffic to
        # the SNAT source no longer goes stale).
        privacyExtensions = "no";
        acceptRAAutonomousPrefix = false;
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
      services.networking.thunderbolt-mesh-of = {
        interfaces = [
          "enp199s0f5"
          "enp199s0f6"
        ];
        loopback.ipv4 = "172.16.255.2/32";
        # Fabric v6 loopbacks: fdfd:cafe:0:ff::/64 reserved for the mesh
        # (pods 0:1::/96, services 0:8001::/112 — see clusters/axon.nix)
        loopback.ipv6 = "fdfd:cafe:0:ff::2/128";
        nsap = "49.0000.0000.0002.00";
      };
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
      disk.xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_192482300001285610CF";
      core.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = true;
      };
    };
  };

  den.aspects.axon-02 = {
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
      hardware.cpu.amd
      hardware.gpu.amd
      services.networking.thunderbolt-mesh-of
    ];
  };
}
