{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.custom.k3s;
in
{
  options.services.custom.k3s = {
    enable = lib.mkOption {
      default = builtins.elem "kubernetes" config.node.deployment.tags;
      type = lib.types.bool;
      description = ''
        Whether to run k3s on this server.
      '';
    };

    role = lib.mkOption {
      default =
        if (builtins.elem "kubernetes-master" config.node.deployment.tags) then "server" else "agent";
      type = lib.types.str;
      description = ''
        Whether to run k3s as a server or an agent.
      '';
    };

    clusterInit = lib.mkOption {
      default = builtins.elem "kubernetes-master" config.node.deployment.tags;
      type = lib.types.bool;
      description = ''
        Whether this node should initialize the K8s cluster.
      '';
    };

    serverAddr = lib.mkOption {
      default = if config.services.custom.clusterInit then null else lib.getKubernetesMasterTargetHost;
      type = with lib.types; nullOr str;
      description = ''
        Address of the server whose cluster this server should join.
        Leaving this empty will make the server initialize the cluster.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    # age.secrets = {
    #   "foo" = {
    #     rekeyFile = lib.relativeToRoot "secrets/foo.age";
    #     owner = "media";
    #     group = "media";
    #   };
    # };

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
              ];
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

              cni = {
                conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d/";
                bin_dir = "${k3s-cni-plugins}/bin";
              };
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

    services = {
      # nix-snapshotter.enable = true;

      # k3s = let
      #   serverFlagList = [
      #     "--image-service-endpoint=unix:///run/nix-snapshotter/nix-snapshotter.sock"
      #     "--snapshotter=overlayfs"
      #     "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
      #     "--tls-san=${config.networking.fqdn}"
      #     "--disable=servicelb"
      #     "--cluster-cidr=10.42.0.0/16,2001:cafe:42::/56"
      #     "--service-cidr=10.43.0.0/16,2001:cafe:43::/112"
      #   ];

      #   serverFlags = builtins.concatStringsSep " " serverFlagList;
      # in {
      #   enable = true;
      #   role = cfg.role;
      #   tokenFile = config.sops.secrets."k3s/serverToken".path;
      #   extraFlags = lib.mkIf (cfg.role == "server") (lib.mkForce serverFlags);
      #   clusterInit = cfg.clusterInit;
      #   serverAddr = lib.mkIf (! (cfg.serverAddr == null)) cfg.serverAddr;
      # };

      # # Required for Longhorn
      # openiscsi = {
      #   enable = true;
      #   name = "iqn.2016-04.com.open-iscsi:${config.networking.fqdn}";
      # };
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
