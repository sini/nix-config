{
  flake.features.kubernetes.nixos =
    {
      inputs,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.nix-snapshotter.nixosModules.default ];

      systemd.services.k3s.requires = [ "containerd.service" ];

      virtualisation.containerd = {
        enable = true;

        settings = {
          version = 2;

          proxy_plugins.nix = {
            type = "snapshot";
            address = "/run/nix-snapshotter/nix-snapshotter.sock";
          };

          plugins =
            let
              k3s-cni-plugins = pkgs.buildEnv {
                name = "k3s-cni-plugins";
                paths = with pkgs; [
                  cni-plugins
                  cni-plugin-flannel
                  pkgs.local.cni-plugin-cilium
                ];
              };
              cniConfig = {
                bin_dir = lib.mkForce "${k3s-cni-plugins}/bin/";
                conf_dir = "/etc/cni/net.d";
              };
            in
            {
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
                containerd.snapshotter = "nix";

                cni = cniConfig;
              };

              "io.containerd.transfer.v1.local".unpack_config = [
                {
                  platform = "linux/amd64";
                  snapshotter = "nix";
                }
              ];
            };
        };

      };

      environment.persistence."/persist".directories = [
        "/var/lib/cni"
        "/var/lib/containers"
        "/var/lib/containerd"
      ];
    };

}
