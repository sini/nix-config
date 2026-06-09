# k3s-containerd — containerd runtime with the zfs snapshotter and Cilium CNI.
#
# Stock nixpkgs containerd ships the zfs snapshotter compiled in (gated only by
# `!no_zfs`, which nixpkgs never sets). It just needs the `zfs` binary on the
# service PATH, since the snapshotter shells out to it. Layers become per-image
# CoW datasets under /var/lib/containerd (its own zfs dataset), so they live
# outside the nix store and are never reaped by nix-collect-garbage. overlayfs
# is the fallback on non-zfs hosts. (nix-snapshotter was retired: no workload
# used nix-backed images and its store-path layers were GC-vulnerable.)
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

        useZfs = host.hasAspect den.aspects.disk.zfs-disk-single;
        snapshotter = if useZfs then "zfs" else "overlayfs";
      in
      {
        systemd.services.k3s.requires = [ "containerd.service" ];

        systemd.services.containerd = {
          serviceConfig.LimitNOFILE = lib.mkForce null;
          path = [
            # mkfs.erofs so the EROFS differ initializes instead of failing —
            # on containerd <2.3.1 a failed EROFS differ breaks the transfer
            # plugin's unpacker ("no unpack platforms defined"), so CRI can't
            # unpack the sandbox image. Fixed upstream in 2.3.1 (#13364); kept
            # here as belt-and-suspenders alongside the version override.
            pkgs.erofs-utils
          ]
          # The zfs snapshotter execs the `zfs` CLI; without it on PATH the
          # plugin fails to init and CRI reports the snapshotter "not found".
          ++ lib.optional useZfs pkgs.zfs;
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

              # In containerd 2.x the CRI plugin is split: snapshotter set under
              # the legacy grpc.v1.cri id migrates to the *runtime* plugin only,
              # leaving the *image* service on the default (overlayfs). Images
              # then unpack into overlayfs while the runtime wants zfs → sandbox
              # "image not found". Set the image service snapshotter explicitly.
              # use_local_image_pull: CRI's transfer-service pull doesn't pass
              # unpack platforms ("no unpack platforms defined"); the local pull
              # unpacks into the CRI snapshotter directly.
              "io.containerd.cri.v1.images" = {
                use_local_image_pull = true;
                snapshotter = snapshotter;
              };

              # Unpack pulled images into the same snapshotter CRI runs on, or
              # CRI can't find the sandbox image's snapshot ("not found").
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
    # dataset (provisioned by zfs-disk-single), so it persists itself and a
    # bind-mount here would shadow the dataset mountpoint.
    persist.directories = [
      "/var/lib/cni"
      "/var/lib/containers"
      "/var/lib/dockershim"
    ];
  };
}
