# k3s-containerd — containerd runtime with overlayfs snapshotter and Cilium CNI.
#
# Uses containerd's built-in overlayfs snapshotter so image layers live in
# /var/lib/containerd (persisted, outside the nix store) and are never reaped
# by nix-collect-garbage. nix-snapshotter was retired (no workload used
# nix-backed images and its store-path layers were GC-vulnerable); a future
# nix-in-pods need will be served by nix-csi as an additive volume driver.
{
  den,
  lib,
  ...
}:
{
  den.aspects.services.k3s.containerd = {
    nixos =
      { host, pkgs, ... }:
      let
        k3s-cni-plugins = pkgs.buildEnv {
          name = "k3s-cni-plugins";
          paths = [
            pkgs.cni-plugins
            pkgs.cni-plugin-flannel
            pkgs.local.cni-plugin-cilium
          ];
        };

        # The zfs snapshotter stores layers as CoW datasets (immune to nix GC);
        # overlayfs is the fallback for non-zfs hosts. The dataset backing
        # /var/lib/containerd is provisioned by the zfs-disk-single aspect.
        useZfs = host.hasAspect den.aspects.disk.zfs-disk-single;
        snapshotter = if useZfs then "zfs" else "overlayfs";
      in
      {
        systemd.services.k3s.requires = [ "containerd.service" ];

        systemd.services.containerd.serviceConfig = {
          LimitNOFILE = lib.mkForce null;
        };

        virtualisation.containerd = {
          enable = true;

          settings = {
            version = 2;

            root = "/var/lib/containerd";
            state = "/run/containerd";

            oom_score = 0;

            grpc = {
              address = "/run/containerd/containerd.sock";
            };

            plugins = {
              "io.containerd.grpc.v1.cri" = {
                stream_server_address = "127.0.0.1";
                stream_server_port = "10010";
                enable_selinux = false;
                enable_unprivileged_ports = true;
                enable_unprivileged_icmp = true;
                disable_apparmor = true;
                disable_cgroup = true;
                restrict_oom_score_adj = true;
                sandbox_image = "rancher/mirrored-pause:3.6";
                containerd.snapshotter = snapshotter;

                cni = {
                  bin_dir = lib.mkForce "${k3s-cni-plugins}/bin/";
                  conf_dir = "/etc/cni/net.d";
                };
              };

              # Unpack pulled images into the same snapshotter CRI runs on,
              # otherwise images land in the default (overlayfs) and CRI — set
              # to zfs — reports the sandbox image "not found".
              "io.containerd.transfer.v1.local".unpack_config = [
                {
                  platform = "linux/amd64";
                  snapshotter = snapshotter;
                }
              ];
            };
          };
        };

        environment.etc = {
          "cni/net.d".enable = false;
          "cni/net.d/05-cilium.conf" = {
            text = builtins.toJSON {
              cniVersion = "0.3.1";
              enable-debug = true;
              log-file = "/var/run/cilium/cilium-cni.log";
              name = "cilium";
              type = "cilium-cni";
            };
            mode = "0644";
          };
        };
      };

    # /var/lib/containerd is intentionally absent: on zfs hosts it is its own
    # dataset (see containerd-zfs-dataset above); the zfs snapshotter manages
    # persistence and a bind-mount would shadow the dataset mountpoint.
    persist.directories = [
      "/var/lib/cni"
      "/var/lib/containers"
      "/var/lib/dockershim"
    ];
  };
}
