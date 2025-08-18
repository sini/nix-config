{
  config,
  lib,
  rootPath,
  ...
}:
let
  hosts = config.flake.hosts;
  kubernetesMasterMap = builtins.listToAttrs (
    map
      (
        { name, value }:
        {
          name = value.tags."kubernetes-cluster";
          value = name;
        }
      )
      (
        lib.filter (
          host:
          builtins.elem "kubernetes-master" (host.value.roles or [ ])
          && host.value.tags ? "kubernetes-cluster"
        ) (lib.attrsToList hosts)
      )
  );
in
{
  flake.modules.nixos.kubernetes =
    {
      lib,
      pkgs,
      config,
      hostOptions,
      ...
    }:
    let
      kubernetesCluster = hostOptions.kubernetes-cluster or "dev";
      isMaster = builtins.elem "kubernetes-master" hostOptions.roles;
      role = if isMaster then "server" else "agent";
      clusterInit = isMaster;
    in
    {
      age.secrets.kubernetes-cluster-token = {
        rekeyFile = rootPath + "/.secrets/k3s/${kubernetesCluster}/k3s-token.age";
      };

      environment.systemPackages = with pkgs; [
        k3s
        openiscsi # Required for Longhorn
        nfs-utils # Required for Longhorn
      ];

      networking = {
        nftables.enable = lib.mkForce false;
        firewall.enable = lib.mkForce false;
      };

      # TODO: Enable Firewall...
      # networking = {
      #   nftables.enable = lib.mkForce false;
      #   firewall = {
      #     enable = lib.mkForce false;
      #     firewall.allowedTCPPorts = [
      #       6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
      #       2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
      #       2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
      #     ];
      #     firewall.allowedUDPPorts = [
      #       8472 # k3s, flannel: required if using multi-node for inter-node networking
      #     ];
      #   };
      # TODO Explore: networking.firewall.trustedInterfaces
      # };

      virtualisation.containerd = {
        enable = true;
        # configFile = "/etc/containerd/config.toml";
        settings = {
          plugins =
            let
              cniConfig = {
                bin_dir = lib.mkForce "/opt/cni/bin";
                conf_dir = "/etc/cni/net.d";
              };
            in
            {
              "io.containerd.cri.v1.runtime".cni = cniConfig;
              "io.containerd.grpc.v1.cri" = {
                cni = cniConfig;
                containerd.runtimes.runc.options.SystemdCgroup = true;
              };
            };
        };
      };
      environment.etc."containerd/config.toml".text = # toml
        ''
          version = 3
          root = "/var/lib/containerd"
          state = "/run/containerd"
          temp = ""
          disabled_plugins = []
          required_plugins = []
          oom_score = 0
          imports = []

          [grpc]
            address = "/run/containerd/containerd.sock"
            tcp_address = ""
            tcp_tls_ca = ""
            tcp_tls_cert = ""
            tcp_tls_key = ""
            uid = 0
            gid = 0
            max_recv_message_size = 16777216
            max_send_message_size = 16777216

          [ttrpc]
            address = ""
            uid = 0
            gid = 0

          [debug]
            address = ""
            uid = 0
            gid = 0
            level = ""
            format = ""

          [metrics]
            address = ""
            grpc_histogram = false

          [plugins]
            [plugins."io.containerd.cri.v1.images"]
              snapshotter = "overlayfs"
              disable_snapshot_annotations = true
              discard_unpacked_layers = false
              max_concurrent_downloads = 3
              concurrent_layer_fetch_buffer = 0
              image_pull_progress_timeout = "5m0s"
              image_pull_with_sync_fs = false
              stats_collect_period = 10
              use_local_image_pull = false

              [plugins."io.containerd.cri.v1.images".pinned_images]
                sandbox = "registry.k8s.io/pause:3.10"

              [plugins."io.containerd.cri.v1.images".registry]
                config_path = ""

              [plugins."io.containerd.cri.v1.images".image_decryption]
                key_model = "node"

            [plugins."io.containerd.cri.v1.runtime"]
              enable_selinux = false
              selinux_category_range = 1024
              max_container_log_line_size = 16384
              disable_apparmor = false
              restrict_oom_score_adj = false
              disable_proc_mount = false
              unset_seccomp_profile = ""
              tolerate_missing_hugetlb_controller = true
              disable_hugetlb_controller = true
              device_ownership_from_security_context = false
              ignore_image_defined_volumes = false
              netns_mounts_under_state_dir = false
              enable_unprivileged_ports = true
              enable_unprivileged_icmp = true
              enable_cdi = true
              cdi_spec_dirs = ["/etc/cdi", "/var/run/cdi"]
              drain_exec_sync_io_timeout = "0s"
              ignore_deprecation_warnings = []

              [plugins."io.containerd.cri.v1.runtime".containerd]
                default_runtime_name = "runc"
                ignore_blockio_not_enabled_errors = false
                ignore_rdt_not_enabled_errors = false

                [plugins."io.containerd.cri.v1.runtime".containerd.runtimes]
                  [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runc]
                    runtime_type = "io.containerd.runc.v2"
                    runtime_path = ""
                    pod_annotations = []
                    container_annotations = []
                    privileged_without_host_devices = false
                    privileged_without_host_devices_all_devices_allowed = false
                    cgroup_writable = false
                    base_runtime_spec = ""
                    cni_conf_dir = ""
                    cni_max_conf_num = 0
                    snapshotter = ""
                    sandboxer = "podsandbox"
                    io_type = ""

                    [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runc.options]
                      BinaryName = ""
                      CriuImagePath = ""
                      CriuWorkPath = ""
                      IoGid = 0
                      IoUid = 0
                      NoNewKeyring = false
                      Root = ""
                      ShimCgroup = ""
                      SystemdCgroup = true

              [plugins."io.containerd.cri.v1.runtime".cni]
                bin_dirs = ["/opt/cni/bin","${pkgs.cni-plugins}/bin"]
                conf_dir = "/etc/cni/net.d"
                max_conf_num = 1
                setup_serially = false
                conf_template = ""
                ip_pref = ""
                use_internal_loopback = false

            [plugins."io.containerd.differ.v1.erofs"]
              mkfs_options = []

            [plugins."io.containerd.gc.v1.scheduler"]
              pause_threshold = 0.02
              deletion_threshold = 0
              mutation_threshold = 100
              schedule_delay = "0s"
              startup_delay = "100ms"

            [plugins."io.containerd.grpc.v1.cri"]
              disable_tcp_service = true
              stream_server_address = "127.0.0.1"
              stream_server_port = "0"
              stream_idle_timeout = "4h0m0s"
              enable_tls_streaming = false

              [plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming]
                tls_cert_file = ""
                tls_key_file = ""

            [plugins."io.containerd.image-verifier.v1.bindir"]
              bin_dir = "/opt/containerd/image-verifier/bin"
              max_verifiers = 10
              per_verifier_timeout = "10s"

            [plugins."io.containerd.internal.v1.opt"]
              path = "/opt/containerd"

            [plugins."io.containerd.internal.v1.tracing"]

            [plugins."io.containerd.metadata.v1.bolt"]
              content_sharing_policy = "shared"
              no_sync = false

            [plugins."io.containerd.monitor.container.v1.restart"]
              interval = "10s"

            [plugins."io.containerd.monitor.task.v1.cgroups"]
              no_prometheus = false

            [plugins."io.containerd.nri.v1.nri"]
              disable = false
              socket_path = "/var/run/nri/nri.sock"
              plugin_path = "/opt/nri/plugins"
              plugin_config_path = "/etc/nri/conf.d"
              plugin_registration_timeout = "5s"
              plugin_request_timeout = "2s"
              disable_connections = false

            [plugins."io.containerd.runtime.v2.task"]
              platforms = ["linux/amd64"]

            [plugins."io.containerd.service.v1.diff-service"]
              default = ["walking"]
              sync_fs = false

            [plugins."io.containerd.service.v1.tasks-service"]
              blockio_config_file = ""
              rdt_config_file = ""

            [plugins."io.containerd.shim.v1.manager"]
              env = []

            [plugins."io.containerd.snapshotter.v1.blockfile"]
              root_path = ""
              scratch_file = ""
              fs_type = ""
              mount_options = []
              recreate_scratch = false

            [plugins."io.containerd.snapshotter.v1.btrfs"]
              root_path = ""

            [plugins."io.containerd.snapshotter.v1.devmapper"]
              root_path = ""
              pool_name = ""
              base_image_size = ""
              async_remove = false
              discard_blocks = false
              fs_type = ""
              fs_options = ""

            [plugins."io.containerd.snapshotter.v1.erofs"]
              root_path = ""
              ovl_mount_options = []
              enable_fsverity = false

            [plugins."io.containerd.snapshotter.v1.native"]
              root_path = ""

            [plugins."io.containerd.snapshotter.v1.overlayfs"]
              root_path = ""
              upperdir_label = false
              sync_remove = false
              slow_chown = false
              mount_options = []

            [plugins."io.containerd.snapshotter.v1.zfs"]
              root_path = ""

            [plugins."io.containerd.tracing.processor.v1.otlp"]

            [plugins."io.containerd.transfer.v1.local"]
              max_concurrent_downloads = 3
              concurrent_layer_fetch_buffer = 0
              max_concurrent_uploaded_layers = 3
              check_platform_supported = false
              config_path = ""

          [cgroup]
            path = ""

          [timeouts]
            "io.containerd.timeout.bolt.open" = "0s"
            "io.containerd.timeout.cri.defercleanup" = "1m0s"
            "io.containerd.timeout.metrics.shimstats" = "2s"
            "io.containerd.timeout.shim.cleanup" = "5s"
            "io.containerd.timeout.shim.load" = "5s"
            "io.containerd.timeout.shim.shutdown" = "3s"
            "io.containerd.timeout.task.state" = "2s"

          [stream_processors]
            [stream_processors."io.containerd.ocicrypt.decoder.v1.tar"]
              accepts = ["application/vnd.oci.image.layer.v1.tar+encrypted"]
              returns = "application/vnd.oci.image.layer.v1.tar"
              path = "ctd-decoder"
              args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
              env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]

            [stream_processors."io.containerd.ocicrypt.decoder.v1.tar.gzip"]
              accepts = ["application/vnd.oci.image.layer.v1.tar+gzip+encrypted"]
              returns = "application/vnd.oci.image.layer.v1.tar+gzip"
              path = "ctd-decoder"
              args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
              env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]    '';

      # virtualisation.containerd = {
      #   enable = true;

      #   settings = {
      #     version = 2;

      #     proxy_plugins.nix = {
      #       type = "snapshot";
      #       address = "/run/nix-snapshotter/nix-snapshotter.sock";
      #     };

      #     plugins =
      #       let
      #         k3s-cni-plugins = pkgs.buildEnv {
      #           name = "k3s-cni-plugins";
      #           paths = with pkgs; [
      #             cni-plugins
      #             cni-plugin-flannel
      #           ];
      #         };
      #       in
      #       {
      #         "io.containerd.grpc.v1.cri" = {
      #           stream_server_address = "127.0.0.1";
      #           stream_server_port = "10010";
      #           enable_selinux = false;
      #           enable_unprivileged_ports = true;
      #           enable_unprivileged_icmp = true;
      #           disable_apparmor = true;
      #           disable_cgroup = true;
      #           restrict_oom_score_adj = true;
      #           sandbox_image = "rancher/mirrored-pause:3.6";
      #           containerd.snapshotter = "nix";

      #           cni = {
      #             conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d/";
      #             bin_dir = "${k3s-cni-plugins}/bin";
      #           };
      #         };

      #         "io.containerd.transfer.v1.local".unpack_config = [
      #           {
      #             platform = "linux/amd64";
      #             snapshotter = "nix";
      #           }
      #         ];
      #       };
      #   };
      # };

      services = {
        k3s =
          let
            serverFlagList = [
              # "--image-service-endpoint=unix:///run/nix-snapshotter/nix-snapshotter.sock"
              # "--snapshotter=overlayfs"
              "--disable local-storage"
              "--disable metrics-server"
              "--disable traefik"
              "--disable servicelb"
              "--flannel-backend=none"
              "--disable-network-policy"
              "--disable-helm-controller"
              "--disable-kube-proxy"
              "--etcd-expose-metrics"
              "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
              "--tls-san=${config.networking.fqdn}"
              "--disable=servicelb"
              #"--cluster-cidr=10.42.0.0/16,2001:cafe:42::/56"
              #"--service-cidr=10.43.0.0/16,2001:cafe:43::/112"
            ];

            serverFlags = builtins.concatStringsSep " " serverFlagList;
          in
          {
            inherit role clusterInit;
            enable = true;
            tokenFile = config.age.secrets.kubernetes-cluster-token.path;
            gracefulNodeShutdown.enable = true;
            extraFlags = lib.mkIf (role == "server") (lib.mkForce serverFlags);
          }
          // lib.optionalAttrs (!isMaster) {
            serverAddr = kubernetesMasterMap.${kubernetesCluster};
          };

        # Required for Longhorn
        openiscsi = {
          enable = true;
          name = "iqn.2016-04.com.open-iscsi:${config.networking.fqdn}";
        };
      };

      # HACK: Symlink binaries to /usr/local/bin such that Longhorn can find them
      # when they use nsenter.
      # https://github.com/longhorn/longhorn/issues/2166#issuecomment-1740179416
      # systemd.tmpfiles.rules = [
      #   "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
      # ];

      #   system.activationScripts = {
      #     k3s-bootstrap = lib.mkIf (cfg.role == "server") {
      #       text = (
      #         let
      #           k3sBootstrapFile =
      #             (inputs.kubenix.evalModules.x86_64-linux {
      #               module = import ./bootstrap.nix;
      #             })
      #             .config
      #             .kubernetes
      #             .result;
      #         in ''
      #           mkdir -p /var/lib/rancher/k3s/server/manifests
      #           ln -sf ${k3sBootstrapFile} /var/lib/rancher/k3s/server/manifests/k3s-bootstrap.json
      #         ''
      #       );
      #     };

      #     k3s-certs = lib.mkIf (cfg.role == "server") {
      #       text = ''
      #         mkdir -p /var/lib/rancher/k3s/server/tls/etcd
      #         cp -f ${./ca/server-ca.crt} /var/lib/rancher/k3s/server/tls/server-ca.crt
      #         cp -f ${./ca/client-ca.crt} /var/lib/rancher/k3s/server/tls/client-ca.crt
      #         cp -f ${./ca/request-header-ca.crt} /var/lib/rancher/k3s/server/tls/request-header-ca.crt
      #         cp -f ${./ca/etcd/peer-ca.crt} /var/lib/rancher/k3s/server/tls/etcd/peer-ca.crt
      #         cp -f ${./ca/etcd/server-ca.crt} /var/lib/rancher/k3s/server/tls/etcd/server-ca.crt
      #       '';
      #     };
      #   };

      #   sops.secrets = let
      #     keyPathBase = "/var/lib/rancher/k3s/server/tls";
      #   in {
      #     "k3s/serverToken" = {
      #       sopsFile = "${self}/secrets/kubernetes.yaml";
      #     };

      #     "k3s/keys/clientCAKey" = {
      #       sopsFile = "${self}/secrets/kubernetes.yaml";
      #       path = "${keyPathBase}/client-ca.key";
      #     };

      #     "k3s/keys/requestHeaderCAKey" = {
      #       sopsFile = "${self}/secrets/kubernetes.yaml";
      #       path = "${keyPathBase}/request-header-ca.key";
      #     };

      #     "k3s/keys/serverCAKey" = {
      #       sopsFile = "${self}/secrets/kubernetes.yaml";
      #       path = "${keyPathBase}/server-ca.key";
      #     };

      #     "k3s/keys/serviceKey" = {
      #       sopsFile = "${self}/secrets/kubernetes.yaml";
      #       path = "${keyPathBase}/service.key";
      #     };

      #     "k3s/keys/etcd/peerCAKey" = {
      #       sopsFile = "${self}/secrets/kubernetes.yaml";
      #       path = "${keyPathBase}/etcd/peer-ca.key";
      #     };

      #     "k3s/keys/etcd/serverCAKey" = {
      #       sopsFile = "${self}/secrets/kubernetes.yaml";
      #       path = "${keyPathBase}/etcd/server-ca.key";
      #     };
      #   };
      # };

      #     networking = {
      #   bridges = {
      #     "${bridge}" = {
      #       interfaces = [ "${interface}" ];
      #     };
      #   };
      #   interfaces.${bridge} = {
      #     useDHCP = false;
      #     ipv4.addresses = [{
      #       address = "${ip}";
      #       prefixLength = subnet;
      #     }];
      #   };
      # };

      #   # use dynamic routing entries
      # systemd.network = {
      #   enable = true;
      #   networks = {
      #     "40-${bridge}" = {
      #       matchConfig.Name = "${bridge}";
      #       networkConfig = {
      #         DHCP = "no";
      #         Address = "${ip}/${toString subnet}";
      #         Gateway = "${gateway}";
      #         DNS = "${dns}";
      #       };
      #       linkConfig = {
      #         RequiredForOnline = "carrier";
      #       };
      #     };
      #   };
      # };
      #   services = {
      #     k3s = {
      #       enable = true;
      #       delay = 100;
      #       prepare = {
      #         cilium = true;
      #       };
      #       services = {
      #         kube-proxy = true;
      #         flux = true;
      #         servicelb = false;
      #         traefik = false;
      #         local-storage = false;
      #         metrics-server = false;
      #         coredns = false;
      #         flannel = false;
      #       };
      #       bootstrap = {
      #         helm = {
      #           enable = true;
      #           completedIf = "get CustomResourceDefinition -A | grep -q 'cilium.io'";
      #           helmfile = "/etc/k3s/helmfile.yaml";
      #         };
      #       };
      #       addons = {
      #         minio = {
      #           enable = true;
      #           credentialsFile = config.age.secrets.minio-credentials.path;
      #           buckets = ["volsync" "postgres"];
      #           dataDir = ["/mnt/backup/minio"];
      #         };
      #       };
      #     };
      #     kvm = {
      #       enable = true;
      #       platform = "${cpu}";
      #       user = "${user}";
      #     };
      #   };
      # };

      # # TODO why do we need to fix the folder permission of mapped age secrets?
      # systemd.tmpfiles.rules = [
      #   "d /mnt/backup 0775 root data -" # must be owned by root to solve gitea folder transition issues!
      #   "d /mnt/hdd/samba 0775 ${user} data -"
      #   "d /opt/k3s 0775 ${user} data -"
      #   "d /opt/k3s/data 0775 ${user} data -"
      #   "d /home/${user}/.config 0775 ${user} data -"
      #   "d /home/${user}/.config/sops 0775 ${user} data -"
      #   "d /home/${user}/.config/sops/age 0775 ${user} data -"
      #   "d /home/${user}/.kube 0775 ${user} data -"
      #   "d /var/lib/rancher/k3s/server/manifests 0775 root data -"
      #   "L /home/${user}/.kube/config  - - - - /etc/rancher/k3s/k3s.yaml"
      #   "L /var/lib/rancher/k3s/server/manifests/flux.yaml - - - - /etc/k3s/flux.yaml"
      #   "L /var/lib/rancher/k3s/server/manifests/flux-git-auth.yaml - - - - ${config.age.secrets.flux-git-auth.path}"
      #   "L /var/lib/rancher/k3s/server/manifests/flux-sops-age.yaml - - - - ${config.age.secrets.flux-sops-age.path}"
      #   "L /var/lib/rancher/k3s/server/manifests/00-coredns-custom.yaml - - - - /etc/k3s/coredns-custom.yaml" # use 00- prefix to deploy this first
      # ];

      # NOTE: we use the ssh key not the git key
      # git url schmeas:
      # - 'git@server02.lan:r/gitops-homelab.git'
      # - 'ssh://git@server02.lan/home/git/r/gitops-homelab.git'
      # - 'ssh://git@server02.lan/~/r/gitops-homelab.git' => ~ is not supported in flux git repo url!
      # flux git secret:
      # 1. flux create secret git flux-git-auth --url="ssh://git@${domain}/~/r/gitops-homelab.git" --private-key-file={{ .PRIVATE_SSH_KEYFILE }} --export > flux-git-secret.yaml
      # 2. manually change the knwon_hosts to `ssh-keyscan -p 22 ${domain}` ssh-ed25519 output
      # 3. encrypt yaml with age
      # environment.etc."k3s/flux.yaml" = {
      #   mode = "0750";
      #   text = ''
      #     apiVersion: source.toolkit.fluxcd.io/v1
      #     kind: GitRepository
      #     metadata:
      #       name: flux-system
      #       namespace: flux-system
      #     spec:
      #       interval: 2m
      #       ref:
      #         branch: main
      #       secretRef:
      #         name: flux-git-auth
      #       url: ssh://gitea@${domain}/r/nixos-k3s.git
      #     ---
      #     apiVersion: kustomize.toolkit.fluxcd.io/v1
      #     kind: Kustomization
      #     metadata:
      #       name: flux-system
      #       namespace: flux-system
      #     spec:
      #       interval: 2m
      #       path: ./kubernetes/flux
      #       prune: true
      #       wait: false
      #       sourceRef:
      #         kind: GitRepository
      #         name: flux-system
      #       decryption:
      #         provider: sops
      #         secretRef:
      #           name: sops-age
      #   '';
      # };

      # environment.etc."k3s/helmfile.yaml" = {
      #   mode = "0750";
      #   text = ''
      #     repositories:
      #       - name: coredns
      #         url: https://coredns.github.io/helm
      #       - name: cilium
      #         url: https://helm.cilium.io
      #     releases:
      #       - name: cilium
      #         namespace: kube-system
      #         # renovate: repository=https://helm.cilium.io
      #         chart: cilium/cilium
      #         version: 1.16.6
      #         values: ["${../../../kubernetes/core/networking/cilium/operator/helm-values.yaml}"]
      #         wait: true
      #       - name: coredns
      #         namespace: kube-system
      #         # renovate: repository=https://coredns.github.io/helm
      #         chart: coredns/coredns
      #         version: 1.38.1
      #         values: ["${../../../kubernetes/core/networking/coredns/app/helm-values.yaml}"]
      #         wait: true
      #   '';
      # };

      # # NOTE this config map is optional used by k3s coredns see https://github.com/k3s-io/k3s/blob/master/manifests/coredns.yaml
      # environment.etc."k3s/coredns-custom.yaml" = {
      #   mode = "0750";
      #   text = ''
      #     apiVersion: v1
      #     kind: ConfigMap
      #     metadata:
      #       name: coredns-custom
      #       namespace: kube-system
      #     data:
      #       domain.server: |
      #         ${domain}:53 {
      #           errors
      #           health
      #           ready
      #           hosts {
      #             ${ip} ${domain}
      #             fallthrough
      #           }
      #           prometheus :9153
      #           forward . /etc/resolv.conf
      #           cache 30
      #           loop
      #           reload
      #           loadbalance
      #         }
      #   '';
      # };

      # # Config for ConBee II
      # environment.etc."ser2net.yaml" = {
      #   mode = "0755";
      #   text = ''
      #     connection: &con01
      #       accepter: tcp,20108
      #       connector: serialdev,/dev/ttyACM0,115200n81,nobreak,local
      #       options:
      #         kickolduser: true
      #   '';
      # };

      # systemd.services.ser2net = {
      #   wantedBy = [ "multi-user.target" ];
      #   description = "Serial to network proxy";
      #   after = [ "network.target" "dev-ttyACM0.device" ];
      #   serviceConfig = {
      #       Type = "simple";
      #       User = "root"; # todo user with only dialout group?
      #       ExecStart = ''${pkgs.ser2net}/bin/ser2net -n -c /etc/ser2net.yaml'';
      #       ExecReload = ''kill -HUP $MAINPID'';
      #       Restart = "on-failure";
      #     };
      # };

      # /*

    };

}
