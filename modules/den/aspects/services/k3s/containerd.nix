# k3s-containerd — containerd runtime with the zfs snapshotter and Cilium CNI.
#
# Stock nixpkgs containerd ships the zfs snapshotter compiled in (gated only by
# `!no_zfs`, which nixpkgs never sets). It just needs the `zfs` binary on the
# service PATH, since the snapshotter shells out to it. Layers become per-image
# CoW datasets under the dedicated child dataset mounted at
# /var/lib/containerd/io.containerd.snapshotter.v1.zfs, so they live outside the
# nix store and are never reaped by nix-collect-garbage. overlayfs
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
            # version 3 is REQUIRED for the split CRI plugin ids below
            # (io.containerd.cri.v1.images / .runtime). Under a version 2 config
            # containerd reads only the legacy io.containerd.grpc.v1.cri block
            # and silently ignores any v3 plugin keys — so the image-service
            # snapshotter/use_local_image_pull settings never took effect and
            # images kept unpacking into overlayfs (sandbox "image not found").
            version = lib.mkForce 3;

            root = "/var/lib/containerd";
            state = "/run/containerd";

            oom_score = 0;

            grpc = {
              address = "/run/containerd/containerd.sock";
            };

            plugins = {
              # CNI stays under the *legacy* grpc.v1.cri id (the only place the
              # nixpkgs module wires it). containerd's version-3 migration folds
              # this block into io.containerd.cri.v1.runtime, converting the
              # singular `bin_dir` into the v3 `bin_dirs` list. Defining cni here
              # rather than directly under cri.v1.runtime avoids the fatal
              # "bin_dir and bin_dirs cannot be set at the same time" — which is
              # what you get if both the migrated and the native key are present.
              "io.containerd.grpc.v1.cri".cni = {
                bin_dir = lib.mkForce "${k3s-cni-plugins}/bin/";
                conf_dir = "/etc/cni/net.d";
              };

              # Image service. snapshotter selects where layers unpack; this is
              # the authoritative snapshotter for CRI in 2.x. use_local_image_pull
              # bypasses the transfer service, whose CRI pull doesn't pass unpack
              # platforms ("no unpack platforms defined"); the local pull unpacks
              # straight into this snapshotter.
              # The sandbox image MUST be fully qualified. The podsandbox
              # controller resolves it via client.GetImage, a raw metadata
              # lookup with no docker.io normalization, while the image is
              # stored under its normalized key (docker.io/...). An unqualified
              # "rancher/mirrored-pause:3.6" therefore never matches → "failed
              # to get sandbox image ... not found".
              "io.containerd.cri.v1.images" = {
                inherit snapshotter;
                use_local_image_pull = true;
                pinned_images.sandbox = "docker.io/rancher/mirrored-pause:3.6";
              };

              # Runtime service. cni intentionally omitted here — it arrives via
              # the grpc.v1.cri migration above. The old v2 config's
              # stream_server_address/port and disable_cgroup are intentionally
              # not carried over: disable_cgroup was removed in containerd 2.x,
              # and the streaming server defaults to 127.0.0.1 on an ephemeral
              # port (localhost-only, so the previously-pinned 10010 served no
              # purpose with the firewall disabled).
              "io.containerd.cri.v1.runtime" = {
                enable_selinux = false;
                enable_unprivileged_ports = true;
                enable_unprivileged_icmp = true;
                disable_apparmor = true;
                restrict_oom_score_adj = true;

                # The runc runtime's snapshotter must match the image service's,
                # or the sandbox controller looks for the pause snapshot in the
                # default snapshotter (overlayfs) while images were unpacked into
                # zfs → "failed to get sandbox image ... not found". An empty
                # value does NOT inherit the image-service snapshotter.
                containerd.runtimes.runc = {
                  runtime_type = "io.containerd.runc.v2";
                  inherit snapshotter;
                };
              };

              # Belt-and-suspenders for any transfer-service path: unpack into
              # the same snapshotter CRI runs on.
              "io.containerd.transfer.v1.local".unpack_config = [
                {
                  platform = "linux/amd64";
                  inherit snapshotter;
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
